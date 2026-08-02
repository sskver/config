{ pkgs }:
pkgs.writeShellScriptBin "discord-post" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail
  : "''${WEBHOOK_URL:?WEBHOOK_URL not set}"
  ${pkgs.curl}/bin/curl -s -H "Content-Type: application/json" -d @- "$WEBHOOK_URL"
''
