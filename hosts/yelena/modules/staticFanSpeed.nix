{ config, lib, pkgs, ... }:

with lib;

{
  options.services.staticFanSpeed = {
    enable = mkEnableOption "static NCT6775 fan speed (fixed PWM, no temp curve)";

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

    pwmValue = mkOption {
      type = types.int;
      default = 70;
      description = "Fixed PWM value to write";
    };
  };

  config = mkIf config.services.staticFanSpeed.enable {
    assertions = [
      {
        assertion = !config.hardware.gpuFanControl.enable
          || (config.hardware.gpuFanControl.pwmPath != config.services.staticFanSpeed.pwmPath);
        message = ''
          services.staticFanSpeed and hardware.gpuFanControl are both enabled and
          both target ${config.services.staticFanSpeed.pwmPath} - they would race
          writing to the same sysfs PWM file. Disable one of them.
        '';
      }
    ];

    systemd.services.set-nct-fan-speed = {
      description = "Configure NCT6775 Fan Speed";

      script = ''
        PATH=$PATH:/run/current-system/sw/bin

        while [ ! -f ${config.services.staticFanSpeed.pwmEnable} ]; do
          sleep 0.2
        done

        echo 1 > ${config.services.staticFanSpeed.pwmEnable}
        echo ${toString config.services.staticFanSpeed.pwmValue} > ${config.services.staticFanSpeed.pwmPath}
      '';

      wantedBy = [ "multi-user.target" ];
      before = [ "local-fs.target" ];
    };
  };
}
