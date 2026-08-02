{ config, lib, pkgs, ... }:

let
  borgDiscord = pkgs.writeShellScriptBin "borg-discord" ''
    #!${pkgs.bash}/bin/bash

    JOB_NAME="$1"
    STATUS="$2"
    ARCHIVE="$3"
    DURATION="$4"
    FILES="$5"
    SIZE="$6"

    : "''${WEBHOOK_URL:?WEBHOOK_URL not set}"

    case "$STATUS" in
      STARTED)
        COLOR=3447003
        TITLE="Borg Backup Started: $JOB_NAME"
        DESCRIPTION="Backup job has started."
        ;;
      SUCCESS)
        COLOR=3066993
        TITLE="Borg Backup Completed: $JOB_NAME"
        DESCRIPTION="Backup finished successfully."
        ;;
      FAILURE)
        COLOR=15158332
        TITLE="Borg Backup Failed: $JOB_NAME"
        DESCRIPTION="Backup finished with errors!"
        ;;
      *)
        COLOR=0
        TITLE="Borg Backup: $JOB_NAME"
        DESCRIPTION=""
        ;;
    esac

    if [ "$STATUS" = "STARTED" ]; then
      JSON=$(${pkgs.jq}/bin/jq -n \
        --arg title "$TITLE" \
        --arg description "$DESCRIPTION" \
        --arg color "$COLOR" \
        --arg timestamp "$(date --iso-8601=seconds)" \
        '{
          embeds: [
            {
              title: $title,
              description: $description,
              color: ($color|tonumber),
              timestamp: $timestamp
            }
          ]
        }'
      )
    else
      JSON=$(${pkgs.jq}/bin/jq -n \
        --arg title "$TITLE" \
        --arg description "$DESCRIPTION" \
        --arg color "$COLOR" \
        --arg timestamp "$(date --iso-8601=seconds)" \
        --arg status "$STATUS" \
        --arg archive "$ARCHIVE" \
        --arg duration "$DURATION" \
        --arg files "$FILES" \
        --arg size "$SIZE" \
        '{
          embeds: [
            {
              title: $title,
              description: $description,
              color: ($color|tonumber),
              timestamp: $timestamp,
              fields: [
                { name: "Status", value: $status, inline: true },
                { name: "Archive", value: $archive, inline: true },
                { name: "Duration", value: $duration, inline: true },
                { name: "Files", value: $files, inline: true },
                { name: "Size", value: $size, inline: true }
              ]
            }
          ]
        }'
      )
    fi

    ${pkgs.curl}/bin/curl -s -H "Content-Type: application/json" -d "$JSON" "$WEBHOOK_URL" || true
  '';

  common-excludes = [
    ".cache"
    "*/cache2"
    "*/Cache"
    ".config/Slack/logs"
    ".config/Code/CachedData"
    ".container-diff"
    ".npm/_cacache"
    "*/node_modules"
    "*/bower_components"
    "*/_build"
    "*/.tox"
    "*/venv"
    "*/.venv"
  ];

  jobNames = [ "local-backup" "nix" "hath" ];

  basicBorgJob = name: {
    encryption = {
      mode = "repokey";
      passCommand = "cat ${config.sops.secrets."borg-passphrase".path}";
    };
    environment.BORG_RSH = "ssh -o 'StrictHostKeyChecking=no' -i /home/skver/.ssh/id_rsa";
    environment.BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK = "yes";
    environment.BORG_RELOCATED_REPO_ACCESS_IS_OK = "yes";
    extraCreateArgs = "--verbose --stats --checkpoint-interval 600";
    repo = "ssh://root@5.83.147.99//mnt/backup/${name}";
    compression = "zstd,6";
    startAt = "weekly";
    user = "skver";

    preHook = ''
      ${borgDiscord}/bin/borg-discord "${name}" "STARTED"
    '';

    postHook = ''
      LOG=$(journalctl -u borgbackup-job-${name}.service -n 50 --no-pager)

      ARCHIVE=$(echo "$LOG" | grep -m1 "Archive name:" | ${pkgs.gawk}/bin/gawk -F': ' '{print $3}' | xargs)
      DURATION=$(echo "$LOG" | grep -m1 "Duration:" | ${pkgs.gawk}/bin/gawk -F': ' '{print $3}' | xargs)
      FILES=$(echo "$LOG" | grep -m1 "Number of files:" | ${pkgs.gawk}/bin/gawk -F': ' '{print $3}' | xargs)
      SIZE=$(echo "$LOG" | grep -m1 "This archive:" | ${pkgs.gawk}/bin/gawk -F': ' '{print $3}' | ${pkgs.gawk}/bin/gawk '{print $1, $2, $3, $4, $5, $6}' | xargs)

      if [ $? -eq 0 ]; then
          STATUS="SUCCESS"
      else
          STATUS="FAILURE"
      fi

      ${borgDiscord}/bin/borg-discord "${name}" "$STATUS" "$ARCHIVE" "$DURATION" "$FILES" "$SIZE" || true
    '';
  };
in
{
  sops.secrets."borg-passphrase" = { };
  sops.secrets."discord-webhook-env" = { };

  services.borgbackup.jobs = {
    local-backup = basicBorgJob "local-backup" // rec {
      paths = [ "/mnt/pool/local-backup" ];
    };

    nix = basicBorgJob "nix" // rec {
      paths = [ "/mnt/pool/nix" ];
    };

    hath = basicBorgJob "hath" // rec {
      paths = [ "/mnt/pool/hath" ];
      exclude = [ "/mnt/pool/hath/download" ];
    };
  };

  systemd.services = lib.genAttrs (map (name: "borgbackup-job-${name}") jobNames) (_: {
    serviceConfig.EnvironmentFile = config.sops.secrets."discord-webhook-env".path;
  });
}
