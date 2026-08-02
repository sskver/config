{ pkgs, ... }:

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
    - Other servers:
        - Grafana (mumu):
            - abbr: GF
              href: http://192.168.0.32:3000
        - mumu (SSH):
            - abbr: SS
              href: ssh://skver@192.168.0.32
        - offsite backup:
            - abbr: OB
              href: ssh://root@5.83.147.99
  '';

  servicesYaml = pkgs.writeText "homepage-services.yaml" ''
    []
  '';

  widgetsYaml = pkgs.writeText "homepage-widgets.yaml" ''
    []
  '';
in
{
  virtualisation.oci-containers.containers."homepage" = {
    image = "ghcr.io/gethomepage/homepage:latest";
    autoStart = true;
    extraOptions = [
      "--pull=always"
    ];
    environment = {
      "HOMEPAGE_ALLOWED_HOSTS" = "192.168.0.104:8017";
    };
    ports = [ "8017:3000" ];
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock:ro"
      "${settingsYaml}:/app/config/settings.yaml:ro"
      "${dockerYaml}:/app/config/docker.yaml:ro"
      "${bookmarksYaml}:/app/config/bookmarks.yaml:ro"
      "${servicesYaml}:/app/config/services.yaml:ro"
      "${widgetsYaml}:/app/config/widgets.yaml:ro"
    ];
  };
}
