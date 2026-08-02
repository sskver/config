# Shared by backup.nix, smart.nix, and modules/smartWebhook.nix: reads a
# Discord embed JSON payload on stdin, posts it to $WEBHOOK_URL. Centralizing
# this avoids the URL-guard/curl-invocation drifting out of sync across the
# three near-identical scripts that used to each carry their own copy.
{ pkgs }:
pkgs.writeShellScriptBin "discord-post" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail
  : "''${WEBHOOK_URL:?WEBHOOK_URL not set}"
  ${pkgs.curl}/bin/curl -s -H "Content-Type: application/json" -d @- "$WEBHOOK_URL"
''
