{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.hardware.gpuFanControl;
  nvidiaPkg = config.hardware.nvidia.package;
  field = if cfg.sensor == "memory" then "temperature.memory" else "temperature.gpu";

  script = pkgs.writeShellScriptBin "gpu-fan-control" ''
    PWM_PATH="${cfg.pwmPath}"
    PWM_ENABLE="${cfg.pwmEnable}"
    GPU_NAME="${if cfg.gpuName == null then "" else cfg.gpuName}"

    MIN_TEMP=${toString cfg.minTemp}
    MAX_TEMP=${toString cfg.maxTemp}
    MIN_PWM=${toString cfg.minPwm}
    MAX_PWM=${toString cfg.maxPwm}
    INVERT=${if cfg.invertPwm then "true" else "false"}

    HYSTERESIS=${toString cfg.hysteresis}

    set_pwm() { echo "$1" > "$PWM_PATH"; }

    # whatever happens to this script, leave the fan at full speed
    trap 'set_pwm $MAX_PWM' EXIT
    trap 'exit 0' TERM INT

    for _ in $(seq 1 150); do [ -f "$PWM_ENABLE" ] && break; sleep 0.2; done

    echo 1 > "$PWM_ENABLE"
    # fail safe: full speed until the first valid temperature reading
    set_pwm $MAX_PWM

    LAST_TEMP=-1000

    while true; do
        TEMP=$(nvidia-smi --query-gpu=name,${field} --format=csv,noheader,nounits 2>/dev/null \
            | grep -i -- "$GPU_NAME" | head -n 1 | awk -F', ' '{print $NF}')

        if ! [[ "$TEMP" =~ ^[0-9]+$ ]]; then
            # no usable reading (driver not ready, GPU reset, N/A): full speed, re-apply on the next good one
            set_pwm $MAX_PWM
            LAST_TEMP=-1000
            sleep 3
            continue
        fi

        if [[ $TEMP -ge $((LAST_TEMP + HYSTERESIS)) || $TEMP -le $((LAST_TEMP - HYSTERESIS)) ]]; then
            if [[ $TEMP -le $MIN_TEMP ]]; then
                RAW_PWM=$MIN_PWM
            elif [[ $TEMP -ge $MAX_TEMP ]]; then
                RAW_PWM=$MAX_PWM
            else
                RAW_PWM=$(( (TEMP - MIN_TEMP) * (MAX_PWM - MIN_PWM) / (MAX_TEMP - MIN_TEMP) + MIN_PWM ))
            fi

            if [[ "$INVERT" == "true" ]]; then
                PWM=$(( MAX_PWM - (RAW_PWM - MIN_PWM) ))
            else
                PWM=$RAW_PWM
            fi

            set_pwm $PWM
            echo "${cfg.sensor} temp: $TEMP°C → PWM: $PWM (Inverted: $INVERT)"

            LAST_TEMP=$TEMP
        fi

        sleep 3
    done
  '';

  wrappedScript = pkgs.symlinkJoin {
    name = "gpu-fan-control-wrapper";
    paths = [ script ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/gpu-fan-control \
        --prefix PATH : ${lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep pkgs.gawk nvidiaPkg ]}
    '';
  };
in
{
  options.hardware.gpuFanControl = {
    enable = mkEnableOption "GPU Fan Control";

    pwmPath = mkOption {
      type = types.str;
      default = "/sys/devices/platform/nct6775.2592/hwmon/hwmon1/pwm1";
      description = "Path to PWM control file";
    };

    pwmEnable = mkOption {
      type = types.str;
      default = "/sys/devices/platform/nct6775.2592/hwmon/hwmon1/pwm1_enable";
      description = "Path to PWM enable file";
    };

    sensor = mkOption {
      type = types.enum [ "gpu" "memory" ];
      default = "gpu";
      description = ''
        Which nvidia-smi temperature drives the fan. HBM cards (P100, V100) throttle on the
        memory temperature, which runs well above the core temperature.
      '';
    };

    gpuName = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "Tesla V100";
      description = ''
        Only use a GPU whose nvidia-smi name contains this (case-insensitive). With several GPUs
        installed this selects the right one; null uses the first GPU nvidia-smi lists.
      '';
    };

    minTemp = mkOption { type = types.int; default = 40; };
    maxTemp = mkOption { type = types.int; default = 75; };
    minPwm  = mkOption { type = types.int; default = 127; };
    maxPwm  = mkOption { type = types.int; default = 255; };
    hysteresis = mkOption { type = types.int; default = 2; };

    invertPwm = mkOption {
      type = types.bool;
      default = false;
      description = "Invert PWM output value (0 = max speed)";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.gpu-fan-control = {
      description = "GPU Fan Control Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      serviceConfig = {
        ExecStart = "${wrappedScript}/bin/gpu-fan-control";
        # if the script is killed hard, still leave the fan at full speed
        ExecStopPost = "${pkgs.runtimeShell} -c 'echo ${toString cfg.maxPwm} > ${cfg.pwmPath}'";
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };
}
