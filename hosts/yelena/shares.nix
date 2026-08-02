{ config, lib, pkgs, ... }:
{
  services.samba-wsdd = {
    enable = true;
  };

  services.samba = {
    enable = true;

    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "zseton";
        "netbios name" = "zseton";
        security = "user";

        "hosts allow" = [ "192.168.0." "127.0.0.1" "localhost" ];
        "hosts deny" = [ "0.0.0.0/0" ];

        "guest account" = "nobody";
        "map to guest" = "bad user";

      # Required for OPL
#      "server min protocol" = "NT1";
#      "server max protocol" = "NT1";
#      "ntlm auth" = "yes";
#      "lanman auth" = "yes";

      # Disable SMB encryption/signing
#      "server signing" = "disabled";

#      "unix extensions" = "no";
      };

      pool = {
        path = "/mnt/pool";
        "read only" = "no";
        browseable = "yes";
        "guest ok" = "no";
        "force user" = "skver";
      };

      ps2 = {
        path = "/mnt/pool/ps2";
        "read only" = "no";
        browseable = "yes";
        "guest ok" = "yes";
        "force user" = "skver";
      };
    };
  };

  /*services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /mnt/pool 192.168.0.102(rw,async,no_subtree_check,anonuid=1000,anongid=1000)
  '';
*/
}
