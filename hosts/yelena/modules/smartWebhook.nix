{ config, pkgs, ... }:

let
  discordPost = import ../lib/discordPost.nix { inherit pkgs; };

  smartWebhook = pkgs.writeShellScriptBin "smartWebhook" ''
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

  environment.systemPackages = [ smartWebhook ];

  systemd.services.smart-discord = {
    description = "Check SMART and send to Discord";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${smartWebhook}/bin/smartWebhook";
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