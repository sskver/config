{ config, pkgs, lib, ... }:

with lib;

let
  nvidiaPkg = config.hardware.nvidia.package;

  script = pkgs.writeShellScriptBin "gpu-fan-control" ''
    PWM_PATH="${config.hardware.gpuFanControl.pwmPath}"
    PWM_ENABLE="${config.hardware.gpuFanControl.pwmEnable}"

    MIN_TEMP=${toString config.hardware.gpuFanControl.minTemp}
    MAX_TEMP=${toString config.hardware.gpuFanControl.maxTemp}
    MIN_PWM=${toString config.hardware.gpuFanControl.minPwm}
    MAX_PWM=${toString config.hardware.gpuFanControl.maxPwm}
    INVERT=${if config.hardware.gpuFanControl.invertPwm then "true" else "false"}

    HYSTERESIS=${toString config.hardware.gpuFanControl.hysteresis}

    echo 1 > "$PWM_ENABLE"

    LAST_TEMP=0
    LAST_PWM=$MIN_PWM

    while true; do
        TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | tail -n 1)

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

            echo $PWM > "$PWM_PATH"
            echo "GPU Temp: $TEMP°C → PWM: $PWM (Inverted: $INVERT)"

            LAST_TEMP=$TEMP
            LAST_PWM=$PWM
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
        --prefix PATH : ${lib.makeBinPath [ pkgs.coreutils nvidiaPkg ]}
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

  config = mkIf config.hardware.gpuFanControl.enable {
    systemd.services.gpu-fan-control = {
      description = "GPU Fan Control Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${wrappedScript}/bin/gpu-fan-control";
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };
}
