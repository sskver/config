{ config, lib, pkgs, ... }:

let
  # kanade and skverspace run with --pull=always against the local registry, so a start fails with
  # "connection refused" while the registry container is up but not yet listening. dependsOn only
  # orders the units, so wait for the registry's HTTP API to answer before docker run.
  registryGate = ''
    for i in $(seq 1 60); do
      curl -sf -o /dev/null http://192.168.0.104:5000/v2/ && break
      sleep 1
    done
  '';
in
{
  sops.secrets."ddns-config-env" = { };
  sops.secrets."hath-env" = { };
  sops.secrets."pihole-env" = { };
  sops.secrets."gitpass" = { };
  sops.secrets."kanade-env" = { };

  systemd.services.docker.after = [
    "zfs-import.target"
    "local-fs.target"
    "mnt-pool-torrents.mount"
    "mnt-pool.mount"
    "mnt-pool-kanade.mount"
    "systemd-tmpfiles-setup.service"
  ];

  systemd.services.docker-kanade.path = [ pkgs.curl ];
  systemd.services.docker-kanade.preStart = lib.mkBefore registryGate;
  systemd.services.docker-skverspace.path = [ pkgs.curl ];
  systemd.services.docker-skverspace.preStart = lib.mkBefore registryGate;

  systemd.tmpfiles.rules = [
    "d /run/valkey 0777 root root -"
    "d /mnt/pool/music 0775 skver users -"
    "d /mnt/pool/music-test 0775 skver users -"
    "d /mnt/pool/slskd 0775 skver users -"
    "d /mnt/pool/slskd/config 0775 skver users -"
    "d /mnt/pool/slskd/downloads 0775 skver users -"
    "d /mnt/pool/soularr 0775 skver users -"
  ];

  virtualisation.docker = {
    enable = true;

    extraOptions = "--insecure-registry 192.168.0.104:5000";
  };

  hardware.nvidia-container-toolkit.enable = true;
  hardware.nvidia-container-toolkit.mount-nvidia-executables = true;

  users.users.skver.extraGroups = [ "docker" ];

/*
  virtualisation.docker.daemon.settings = {
    data-root = "/mnt/pool/docker-storage";
  };
*/

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      "registry" = {
        image = "registry:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["5000:5000"];
        volumes = [
          "/var/lib/docker-registry:/var/lib/registry:rw"
        ];
        labels = {
          "homepage.group" = "Infrastructure";
          "homepage.name" = "Docker Registry";
          "homepage.icon" = "docker.png";
          "homepage.href" = "http://192.168.0.104:5000";
        };
      };
      "ddns-updater" = {
        image = "qmcgaw/ddns-updater:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["8001:8000"];
        environmentFiles = [ config.sops.secrets."ddns-config-env".path ];
        labels = {
          "homepage.group" = "Infrastructure";
          "homepage.name" = "DDNS Updater";
          "homepage.icon" = "ddns-updater.png";
          "homepage.href" = "http://192.168.0.104:8001";
        };
      };
      "nginxui" = {
        image = "uozi/nginx-ui:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        labels = {
          "homepage.group" = "Infrastructure";
          "homepage.name" = "Nginx UI";
          "homepage.icon" = "nginx.png";
          "homepage.href" = "http://192.168.0.104:8002";
        };
        environment = {
          "TZ" = "Europe/Budapest";
           #NGINX_UI_IGNORE_DOCKER_SOCKET: true
          "NGINX_UI_SERVER_PORT" = "9000";
        };
        ports = [
          "8002:9000"
          "443:443"
          "80:80"
        ];
        volumes = [
          "nginx:/etc/nginx"
          "nginxui:/etc/nginx-ui"
          "/var/run/docker.sock:/var/run/docker.sock"
          "/mnt/pool/www:/var/www"
        ];
      };
      "hath" = {
        image = "d0v0b/hentaiathome:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["65534:65534"];
        volumes = [ "/mnt/pool/hath:/hath" ];
        environmentFiles = [ config.sops.secrets."hath-env".path ];
      };
      "rflood" = {
        image = "ghcr.io/hotio/rflood:release-0.9.8-r16--4.6.1"; #release-v0.16.18" still fucking awful and broken; #release-476d64b"; # latest -> release-65666ac -> release, maybe use latest? -> idfk this shits broken: release-476d64b, release-0.9.8-r16--4.6.1
        autoStart = true;
        extraOptions = [
          "--pull=always"
          "--ulimit=nofile=16384:16384"
        ];
        volumes = [
          "/mnt/pool/rtorrent:/config"
          "/mnt/pool/torrents:/mnt"
        ];
        ports = [
          "50000:50000"
          "6881:6881"
          "3000:3000"
        ];
        environment = {
          "PUID" = "1000";
          "PGID" = "1000";
          "UMASK" = "000";
          "FLOOD_AUTH" = "false";
        };
        labels = {
          "homepage.group" = "Downloads";
          "homepage.name" = "Flood";
          "homepage.icon" = "flood.png";
          "homepage.href" = "http://192.168.0.104:3000";
        };
      };
      "jellyfin" = {
        image = "linuxserver/jellyfin:latest";
        autoStart = true;
        extraOptions = [
          "--device=nvidia.com/gpu=all"
          "--pull=always"
        ];
        environment = {
          "NVIDIA_VISIBLE_DEVICES" = "all";
        };
        ports = [
          "8096:8096"
        ];
        volumes = [
          "jellyfin-data:/config"
          "/mnt/pool/torrents:/mnt"
        ];
        labels = {
          "homepage.group" = "Media";
          "homepage.name" = "Jellyfin";
          "homepage.icon" = "jellyfin.png";
          "homepage.href" = "http://192.168.0.104:8096";
        };
      };
      "pihole" = {
        image = "pihole/pihole:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = [
          "192.168.0.104:53:53/tcp"
          "192.168.0.104:53:53/udp"
          "8003:80/tcp"
        ];
        environment = {
          "TZ" = "Europe/Budapest";
        };
        environmentFiles = [ config.sops.secrets."pihole-env".path ];
        volumes = [
          "pihole-data:/etc/pihole"
          "pihole-dns:/etc/dnsmasq.d"
        ];
        labels = {
          "homepage.group" = "Infrastructure";
          "homepage.name" = "Pi-hole";
          "homepage.icon" = "pi-hole.png";
          "homepage.href" = "http://192.168.0.104:8003/admin";
        };
      };
      "prowlarr" = {
        image = "linuxserver/prowlarr:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["8004:9696"];
        volumes = [ "prowlarr-data:/config" ];
        environment = {
          "PUID" = "1000";
          "PGID" = "1000";
          "TZ" = "Europe/Budapest";
        };
        labels = {
          "homepage.group" = "Downloads";
          "homepage.name" = "Prowlarr";
          "homepage.icon" = "prowlarr.png";
          "homepage.href" = "http://192.168.0.104:8004";
        };
      };
      "sonarr" = {
        image = "linuxserver/sonarr:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["8005:8989"];
        volumes = [
          "sonarr-data:/config"
          "/mnt/pool/torrents:/mnt"
        ];
        environment = {
          "PUID" = "1000";
          "PGID" = "1000";
          "TZ" = "Europe/Budapest";
        };
        labels = {
          "homepage.group" = "Downloads";
          "homepage.name" = "Sonarr";
          "homepage.icon" = "sonarr.png";
          "homepage.href" = "http://192.168.0.104:8005";
        };
      };
      "radarr" = {
        image = "linuxserver/radarr:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["8006:7878"];
        volumes = [
          "radarr-data:/config"
          "/mnt/pool/torrents:/mnt"
        ];
        environment = {
          "PUID" = "1000";
          "PGID" = "1000";
          "TZ" = "Europe/Budapest";
        };
        labels = {
          "homepage.group" = "Downloads";
          "homepage.name" = "Radarr";
          "homepage.icon" = "radarr.png";
          "homepage.href" = "http://192.168.0.104:8006";
        };
      };
      "lidarr" = {
        image = "linuxserver/lidarr:nightly";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["8019:8686"];
        volumes = [
          "lidarr-data:/config"
          "/mnt/pool/music:/music"
          "/mnt/pool/slskd/downloads:/downloads"
        ];
        environment = {
          "PUID" = "1000";
          "PGID" = "1000";
          "TZ" = "Europe/Budapest";
        };
        labels = {
          "homepage.group" = "Downloads";
          "homepage.name" = "Lidarr";
          "homepage.icon" = "lidarr.png";
          "homepage.href" = "http://192.168.0.104:8019";
        };
      };
      "lidarr-test" = {
        image = "linuxserver/lidarr:nightly";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["8021:8686"];
        volumes = [
          "lidarr-test-data:/config"
          "/mnt/pool/music-test:/music"
          "/mnt/pool/slskd/downloads:/downloads"
        ];
        environment = {
          "PUID" = "1000";
          "PGID" = "1000";
          "TZ" = "Europe/Budapest";
        };
        labels = {
          "homepage.group" = "Downloads";
          "homepage.name" = "Lidarr (test)";
          "homepage.icon" = "lidarr.png";
          "homepage.href" = "http://192.168.0.104:8021";
        };
      };
      "slskd" = {
        image = "slskd/slskd:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = [
          "8020:5030"
          "50300:50300"
        ];
        volumes = [
          "/mnt/pool/slskd/config:/app"
          "/mnt/pool/slskd/downloads:/downloads"
          "/mnt/pool/music:/music:ro"
        ];
        environment = {
          "PUID" = "1000";
          "PGID" = "1000";
          "TZ" = "Europe/Budapest";
          "SLSKD_REMOTE_CONFIGURATION" = "true";
          "SLSKD_DOWNLOADS_DIR" = "/downloads";
        };
        labels = {
          "homepage.group" = "Downloads";
          "homepage.name" = "slskd";
          "homepage.icon" = "slskd.png";
          "homepage.href" = "http://192.168.0.104:8020";
        };
      };
      "skverspace" = {
        image = "192.168.0.104:5000/skver.space/web:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["8007:3000"];
        dependsOn = [ "registry" ];
        labels = {
          "homepage.group" = "Infrastructure";
          "homepage.name" = "skver.space";
          "homepage.icon" = "mdi-web";
          "homepage.href" = "http://192.168.0.104:8007";
        };
      };
      "kanade" = {
        image = "192.168.0.104:5000/skver/kanade:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["8018:3000"];
        dependsOn = [ "registry" ];
        environment = {
          "ORIGIN" = "https://kanade.stream";
          "DATA_DIR" = "/data";
          "KANADE_DIR" = "/state";
          "DISCORD_CLIENT_ID" = "1544362500307550328";
          "DISCORD_REDIRECT_URI" = "https://kanade.stream/auth/discord/callback";
          "KANADE_ADMIN_DISCORD_IDS" = "212558627016409088";
          "SESSION_TTL_DAYS" = "30";
          "VALKEY_URL" = "/var/run/valkey/valkey.sock";
          "KANADE_PREFER_TRANSLATOR" = "qwen,gemma";
        };
        environmentFiles = [ config.sops.secrets."kanade-env".path ];
        volumes = [
          "/mnt/pool/kanade/media:/data:ro"
          "/mnt/pool/kanade/state:/state"
          "/run/valkey:/var/run/valkey"
        ];
        labels = {
          "homepage.group" = "Media";
          "homepage.name" = "Kanade";
          "homepage.icon" = "mdi-music";
          "homepage.href" = "https://kanade.stream";
        };
      };
      "jellyseerr" = {
        image = "seerr/seerr:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        environment = {
          "TZ" = "Europe/Budapest";
        };
        ports = ["8008:5055"];
        volumes = [ "jellyseerr-data:/app/config" ];
        labels = {
          "homepage.group" = "Media";
          "homepage.name" = "Jellyseerr";
          "homepage.icon" = "jellyseerr.png";
          "homepage.href" = "http://192.168.0.104:8008";
        };
      };
      "forgejo" = {
        image = "codeberg.org/forgejo/forgejo:16";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = [
          "3001:3000"
          "22:22"
        ];
        environment = {
          "USER_UID" = "1000";
          "USER_GID" = "1000";
        };
        volumes = [
          "/mnt/pool/forgejo:/data"
          "/etc/localtime:/etc/localtime:ro"
        ];
        labels = {
          "homepage.group" = "Infrastructure";
          "homepage.name" = "Forgejo";
          "homepage.icon" = "forgejo.png";
          "homepage.href" = "http://192.168.0.104:3001";
        };
      };

    dind = {
      image = "docker:dind";
      cmd = [ "dockerd" "-H" "tcp://0.0.0.0:2375" "--tls=false" ];
      volumes = [ "/var/lib/forgejo-runner/dind:/var/lib/docker"];
      extraOptions = [
        "--privileged"
        "--network=forgejo-net"
      ];
      autoStart = true;
    };

    forgejo-runner = {
      image = "data.forgejo.org/forgejo/runner:12";
      dependsOn = [ "dind" ];
      environment.DOCKER_HOST = "tcp://dind:2375";
      user = "1001:1001";
      volumes = [ "/var/lib/forgejo-runner/data:/data" ];
      cmd = [ "forgejo-runner" "daemon" "--config" "runner-config.yml" ];
      extraOptions = [ "--network=forgejo-net" "--link=dind" ];
      autoStart = true;
    };

#      "raraku-backend" = {
#        image = "git.skver.space/raraku/raraku-backend:latest";
#        extraOptions = [
#          "--pull=always"
#        ];
#        autoStart = true;
#        ports = ["8009:3000"];
#        volumes = [
#          "/mnt/pool/raraku-data:/app/public"
#        ];
#        login = {
#          username = "skver";
#          passwordFile = config.sops.secrets."gitpass".path;
#          registry = "https://git.skver.space/";
#        };
#      };
#      "raraku-frontend" = {
#        image = "git.skver.space/raraku/raraku-frontend:latest";
#        extraOptions = [
#          "--pull=always"
#        ];
#        autoStart = true;
#        ports = ["8010:3000"];
#        login = {
#          username = "skver";
#          passwordFile = config.sops.secrets."gitpass".path;
#          registry = "https://git.skver.space/";
#        };
#      };
/*      "raraku-ai" = {
        image = "git.skver.space/raraku/raraku-ai-microservice:latest";
        extraOptions = [
          "--device=nvidia.com/gpu=all"
          "--pull=always"
        ];
        environment = {
          "NVIDIA_VISIBLE_DEVICES" = "all";
        };
        volumes = [
          "/mnt/pool/raraku-data:/mnt"
        ];
        autoStart = true;
        ports = ["8014:8000"];
        login = {
          username = "skver";
          passwordFile = config.sops.secrets."gitpass".path;
          registry = "https://git.skver.space/";
        };
      };*/

      "calibre-web" = {
        image = "linuxserver/calibre-web:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        environment = {
          "TZ" = "Europe/Budapest";
          "PUID" = "1000";
          "PGID" = "1000";
          "DOCKER_MODS" = "linuxserver/mods:universal-calibre";
        };
        ports = ["8015:8083"];
        volumes = [
          "/mnt/pool/calibre/data:/config"
          "/mnt/pool/calibre/library:/books"
        ];
        labels = {
          "homepage.group" = "Media";
          "homepage.name" = "Calibre-Web";
          "homepage.icon" = "calibre-web.png";
          "homepage.href" = "http://192.168.0.104:8015";
        };
      };
      "calibre-websync" = {
        image = "vincentbitter/koreader-calibre-web-sync:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["8016:5000"];
        labels = {
          "homepage.group" = "Media";
          "homepage.name" = "Calibre KOReader Sync";
          "homepage.icon" = "mdi-book-sync";
          "homepage.href" = "http://192.168.0.104:8016";
        };
      };
      "fastapi-dls" = {
        image = "collinwebdesigns/fastapi-dls:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["1443:443"];
        volumes = [
          "/mnt/pool/fastapi-dls/cert:/app/cert"
          "/mnt/pool/fastapi-dls/db:/app/database"
          ];
        environment = {
          "DLS_URL" = "192.168.0.104";
          "DLS_PORT" = "1443";
          "TZ" = "Europe/Budapest";
        };
        labels = {
          "homepage.group" = "Infrastructure";
          "homepage.name" = "FastAPI-DLS";
          "homepage.icon" = "mdi-nvidia";
          "homepage.href" = "https://192.168.0.104:1443";
        };
      };

      "node-exporter" = {
        image = "prom/node-exporter:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = [
          "9100:9100"
        ];
        volumes = [
          "/proc:/host/proc:ro"
          "/sys:/host/sys:ro"
          "/:/rootfs:ro"
        ];
        cmd = [
          "--path.procfs=/host/proc"
          "--path.rootfs=/rootfs"
          "--path.sysfs=/host/sys"
          "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
        ];
      };

      "cadvisor" = {
        image = "gcr.io/cadvisor/cadvisor:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = [ "8080:8080" ];
        volumes = [
          "/:/rootfs:ro"
          "/var/run:/var/run:rw"
          "/sys:/sys:ro"
          "/var/lib/docker/:/var/lib/docker:ro"
        ];
      };

      "dem" = {
        image = "quaide/dem:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
          "/mnt/pool/dem/conf.yml:/app/conf.yml"
        ];
      };

      "alloy" = {
        image = "grafana/alloy:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        volumes = [
          "/mnt/pool/alloy/alloy.hcl:/etc/alloy/config.alloy:ro"
          "/mnt/pool/alloy/log:/var/log:ro"
          "/var/lib/docker/containers:/var/lib/docker/containers:ro"
          "/var/run/docker.sock:/var/run/docker.sock"
          "/mnt/pool/alloy/positions:/positions"
        ];
        cmd = [ "run" "--storage.path=/positions" "/etc/alloy/config.alloy" ];
      };
      valkey = {
        image = "valkey/valkey:9.1.2-alpine";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        cmd = [
          "valkey-server"
          "--port" "0"
          "--unixsocket" "/var/run/valkey/valkey.sock"
          "--unixsocketperm" "777"
          "--save" ""
          "--appendonly" "no"
          "--maxmemory" "256mb"
          "--maxmemory-policy" "allkeys-lfu"
        ];
        volumes = [
          "/run/valkey:/var/run/valkey"
        ];
      };
    };
  };
}
