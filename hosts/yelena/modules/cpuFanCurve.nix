{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.cpuFanCurve;
in
{
  options.services.cpuFanCurve = {
    enable = mkEnableOption "NCT6775 SmartFan IV curve for the CPU fan header (pwm2)";

    hwmonDir = mkOption {
      type = types.str;
      default = "/sys/devices/platform/nct6775.2592/hwmon/hwmon1";
      description = "hwmon directory of the NCT6775 chip";
    };

    points = mkOption {
      type = types.listOf types.int;
      default = [ 64 90 140 255 255 ];
      description = "pwm (0-255) at the five auto points; the temperatures stay at the firmware's values";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.cpu-fan-curve = {
      description = "NCT6775 CPU fan curve";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "60s";
      };
      script = ''
        for _ in $(seq 1 150); do
          [ -f ${cfg.hwmonDir}/pwm2_auto_point1_pwm ] && break
          sleep 0.2
        done

        i=1
        for v in ${concatMapStringsSep " " toString cfg.points}; do
          echo $v > ${cfg.hwmonDir}/pwm2_auto_point''${i}_pwm
          i=$((i+1))
        done
      '';
    };
  };
}
