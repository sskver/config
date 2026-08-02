{ config, lib, pkgs, ... }:

{
  sops.secrets."ddns-config-env" = { };
  sops.secrets."hath-env" = { };
  sops.secrets."pihole-env" = { };
  sops.secrets."gitpass" = { };

  systemd.services.docker.after = [
    "zfs-import.target"
    "local-fs.target"
    "mnt-pool-torrents.mount"
    "mnt-pool.mount"
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
      };
      "ddns-updater" = {
        image = "qmcgaw/ddns-updater:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["8001:8000"];
        environmentFiles = [ config.sops.secrets."ddns-config-env".path ];
      };
      "nginxui" = {
        image = "uozi/nginx-ui:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
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
      };
      "skverspace" = {
        image = "192.168.0.104:5000/skver.space/web:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["8007:3000"];
        dependsOn = [ "registry" ];
      };
      "jellyseerr" = {
        image = "fallenbagel/jellyseerr:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        environment = {
          "TZ" = "Europe/Budapest";
        };
        ports = ["8008:5055"];
        volumes = [ "jellyseerr-data:/app/config" ];
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
      };
      "calibre-websync" = {
        image = "vincentbitter/koreader-calibre-web-sync:latest";
        autoStart = true;
        extraOptions = [
          "--pull=always"
        ];
        ports = ["8016:5000"];
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
    };
  };
}
