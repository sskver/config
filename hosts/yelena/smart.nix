# All SMART -> Discord monitoring lives here: an event-driven per-device
# smartd hook (fires the moment smartd flags an actual issue) plus a daily
# heartbeat poll (so you get a "still alive" status even when nothing's
# wrong). Previously split across this file and modules/smartWebhook.nix
# as two independently-evolved copies of near-identical code.
{ config, lib, pkgs, ... }:

let
  discordPost = import ./lib/discordPost.nix { inherit pkgs; };

  smartdDiscordNotify = pkgs.writeShellScriptBin "smartdDiscordNotify" ''
    #!${pkgs.bash}/bin/bash
      : "''${WEBHOOK_URL:?WEBHOOK_URL not set}"
      HOSTNAME=$(< /proc/sys/kernel/hostname)
      DATE=$(${pkgs.coreutils}/bin/date --iso-8601=seconds)

      # smartd passes these environment variables
      DEV="$SMARTD_DEVICE"
      EVENT="$SMARTD_EVENT"
      MSG="$SMARTD_MESSAGE"

      JSON=$(${pkgs.jq}/bin/jq -n \
          --arg title "SMART Alert: $HOSTNAME" \
          --arg dev "$DEV" \
          --arg event "$EVENT" \
          --arg message "$MSG" \
          --arg timestamp "$DATE" \
          '{embeds:[{title:$title, fields:[{name:"Device",value:$dev,inline:true},{name:"Event",value:$event,inline:true},{name:"Details",value:$message,inline:false}],color:15105570,timestamp:$timestamp}]}'
      )

      echo "$JSON" | ${discordPost}/bin/discord-post
  '';

  smartDailyCheck = pkgs.writeShellScriptBin "smartDailyCheck" ''
    #!${pkgs.bash}/bin/bash
    : "''${WEBHOOK_URL:?WEBHOOK_URL not set}"
    HOSTNAME=$(< /proc/sys/kernel/hostname)
    DATE=$(${pkgs.coreutils}/bin/date --iso-8601=seconds)

    OUTPUT=$(for dev in /dev/sd?; do
        ${pkgs.smartmontools}/bin/smartctl -H $dev 2>/dev/null | grep "SMART overall-health" | ${pkgs.gawk}/bin/gawk -v d="$dev" '{print d ": " $6}'
    done)

    JSON=$(${pkgs.jq}/bin/jq -n \
        --arg title "SMART Status: $HOSTNAME" \
        --arg description "$OUTPUT" \
        --arg timestamp "$DATE" \
        '{embeds:[{title:$title, description:$description, color:15105570, timestamp:$timestamp}]}'
    )

    echo "$JSON" | ${discordPost}/bin/discord-post
  '';
in
{
  sops.secrets."discord-webhook-env" = { };

  environment.systemPackages = [ smartdDiscordNotify smartDailyCheck ];

  systemd.services.smartd.serviceConfig.EnvironmentFile = config.sops.secrets."discord-webhook-env".path;

  services.smartd = {
    enable = true;
    notifications.test = true;

    # Devices, same as your config
    devices = [
      {
        device = "/dev/disk/by-id/ata-TOSHIBA_DT01ACA300_37A55Y0AS";  # 8 year old, still going strong, need to be replaced soon
        options = "-M exec ${smartdDiscordNotify}/bin/smartdDiscordNotify";
      }
      /*{
        device = "/dev/disk/by-id/ata-TOSHIBA_DT01ACA300_35PPKL7GS";
        options = "-M exec ${smartdDiscordNotify}/bin/smartdDiscordNotify";
      }*/ # almost 10 years old, rest in raid-land :'(
      {
        device = "/dev/disk/by-id/ata-ST4000VN008-2DR166_ZGY8QNK4";
        options = "-M exec ${smartdDiscordNotify}/bin/smartdDiscordNotify"; # hardverapro special, 4TB NAS drive, was used for 4.8 years CHIA farming
      }
      {
        device = "/dev/disk/by-id/ata-TOSHIBA_HDWD130_1154KU5AS";
        options = "-M exec ${smartdDiscordNotify}/bin/smartdDiscordNotify";
      }
      # one of these toshiba fuckers has ONE bad sector, crazy aah
      {
        device = "/dev/disk/by-id/ata-TOSHIBA_HDWD130_Y0O2VMDAS";
        options = "-M exec ${smartdDiscordNotify}/bin/smartdDiscordNotify";
      }
      {
        device = "/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S649NL0TB54012A";
        options = "-M exec ${smartdDiscordNotify}/bin/smartdDiscordNotify";
      }
    ];

    # defaults for all devices
    defaults.monitored = "-a -o on -s (S/../.././02|L/../../7/04)";
  };

  systemd.services.smart-discord = {
    description = "Check SMART and send to Discord";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${smartDailyCheck}/bin/smartDailyCheck";
      EnvironmentFile = config.sops.secrets."discord-webhook-env".path;
    };
  };

  systemd.timers.smart-discord = {
    description = "Run SMART check every day at 8am";
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };
}
