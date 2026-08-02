# The static counterpart to gpuFanControl.nix: pins the NCT6775 fan at a
# fixed PWM value instead of driving it off a temperature curve. Both write
# to the same sysfs pwm path, so they're mutually exclusive — asserted below
# rather than left to race silently if both ever get enabled at once.
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

      # Small loop to wait for the sysfs files to appear, ensuring hardware
      # is ready before writing (driver can load late).
      script = ''
        PATH=$PATH:/run/current-system/sw/bin

        while [ ! -f ${config.services.staticFanSpeed.pwmEnable} ]; do
          sleep 0.2
        done

        echo 1 > ${config.services.staticFanSpeed.pwmEnable}
        echo ${toString config.services.staticFanSpeed.pwmValue} > ${config.services.staticFanSpeed.pwmPath}
      '';

      # Run after basic system initialization, before local filesystems
      wantedBy = [ "multi-user.target" ];
      before = [ "local-fs.target" ];
    };
  };
}
