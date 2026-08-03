{ config, pkgs, ... }:

let
  settingsYaml = pkgs.writeText "homepage-settings.yaml" ''
    title: yelena
    theme: dark
    color: slate
    headerStyle: boxed
    layout:
      Media:
        style: row
        columns: 3
      Downloads:
        style: row
        columns: 3
      Infrastructure:
        style: row
        columns: 3
      Other servers:
        style: row
        columns: 3
  '';

  dockerYaml = pkgs.writeText "homepage-docker.yaml" ''
    yelena:
      socket: /var/run/docker.sock
  '';

  bookmarksYaml = pkgs.writeText "homepage-bookmarks.yaml" ''
    []
  '';

  servicesYaml = pkgs.writeText "homepage-services.yaml" ''
    - Infrastructure:
        - grafana (mumu):
            icon: grafana.png
            href: http://192.168.0.32:3000
            description: metrics & dashboards on mumu
            widget:
              type: grafana
              version: 2
              url: http://192.168.0.32:3000
              username: admin
              password: "{{HOMEPAGE_FILE_GRAFANA_PASSWORD}}"
    - Other servers:
        - mumu (ssh):
            icon: mdi-server
            href: ssh://skver@192.168.0.32
            description: 192.168.0.32
            widget:
              type: prometheusmetric
              url: http://192.168.0.32:9090
              refreshInterval: 10000
              metrics:
                - label: cpu
                  query: 100 - (avg(rate(node_cpu_seconds_total{mode="idle",server="mumu"}[1m])) * 100)
                  format:
                    type: percent
                - label: mem
                  query: (1 - (node_memory_MemAvailable_bytes{server="mumu"} / node_memory_MemTotal_bytes{server="mumu"})) * 100
                  format:
                    type: percent
                - label: disk
                  query: 100 - ((node_filesystem_avail_bytes{server="mumu",mountpoint="/"} / node_filesystem_size_bytes{server="mumu",mountpoint="/"}) * 100)
                  format:
                    type: percent
                - label: net
                  query: sum(rate(node_network_receive_bytes_total{server="mumu",device!~"lo|veth.*|docker.*|br-.*"}[1m])) + sum(rate(node_network_transmit_bytes_total{server="mumu",device!~"lo|veth.*|docker.*|br-.*"}[1m]))
                  format:
                    type: byterate
        - offsite backup:
            icon: mdi-cloud-upload-outline
            href: ssh://root@5.83.147.99
            description: 5.83.147.99
            widget:
              type: prometheusmetric
              url: http://192.168.0.32:9090
              refreshInterval: 10000
              metrics:
                - label: cpu
                  query: 100 - (avg(rate(node_cpu_seconds_total{mode="idle",server="offsite"}[1m])) * 100)
                  format:
                    type: percent
                - label: mem
                  query: (1 - (node_memory_MemAvailable_bytes{server="offsite"} / node_memory_MemTotal_bytes{server="offsite"})) * 100
                  format:
                    type: percent
                - label: disk
                  query: 100 - ((node_filesystem_avail_bytes{server="offsite",mountpoint="/"} / node_filesystem_size_bytes{server="offsite",mountpoint="/"}) * 100)
                  format:
                    type: percent
                - label: net
                  query: sum(rate(node_network_receive_bytes_total{server="offsite",device!~"lo|veth.*|docker.*|br-.*"}[1m])) + sum(rate(node_network_transmit_bytes_total{server="offsite",device!~"lo|veth.*|docker.*|br-.*"}[1m]))
                  format:
                    type: byterate
  '';

  widgetsYaml = pkgs.writeText "homepage-widgets.yaml" ''
    - resources:
        cpu: true
        memory: true
        uptime: true
        network: br0
        disk: /rootfs
    - resources:
        label: storage
        disk:
          - /rootfs/mnt/pool
  '';

  customCss = pkgs.writeText "homepage-custom.css" ''
    body, body * {
      font-family: "JetBrains Mono", "Fira Code", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace !important;
      text-transform: lowercase;
      letter-spacing: 0.02em;
    }

    input, textarea {
      text-transform: none;
    }

    html, #__next {
      background: transparent !important;
    }

    body {
      background-color: #0b1120 !important;
      background-image:
        radial-gradient(circle at 12% -10%, rgba(56, 189, 248, 0.10), transparent 45%),
        radial-gradient(circle at 88% 0%, rgba(129, 140, 248, 0.10), transparent 45%),
        repeating-linear-gradient(0deg, rgba(255, 255, 255, 0.035) 0px, rgba(255, 255, 255, 0.035) 1px, transparent 1px, transparent 28px),
        repeating-linear-gradient(90deg, rgba(255, 255, 255, 0.035) 0px, rgba(255, 255, 255, 0.035) 1px, transparent 1px, transparent 28px);
      background-attachment: fixed;
    }
  '';
in
{
  sops.secrets."grafana-admin-password" = {};

  virtualisation.oci-containers.containers."homepage" = {
    image = "ghcr.io/gethomepage/homepage:latest";
    autoStart = true;
    extraOptions = [
      "--pull=always"
      "--network=host"
    ];
    environment = {
      "HOMEPAGE_ALLOWED_HOSTS" = "192.168.0.104:8017";
      "HOMEPAGE_FILE_GRAFANA_PASSWORD" = "/run/secrets/grafana-admin-password";
      "PORT" = "8017";
    };
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock:ro"
      "/:/rootfs:ro"
      "/sys:/sys:ro"
      "${config.sops.secrets."grafana-admin-password".path}:/run/secrets/grafana-admin-password:ro"
      "${settingsYaml}:/app/config/settings.yaml:ro"
      "${dockerYaml}:/app/config/docker.yaml:ro"
      "${bookmarksYaml}:/app/config/bookmarks.yaml:ro"
      "${servicesYaml}:/app/config/services.yaml:ro"
      "${widgetsYaml}:/app/config/widgets.yaml:ro"
      "${customCss}:/app/config/custom.css:ro"
    ];
  };
}
