# Settings genuinely identical between yoi and yelena. Anything that's only
# superficially similar (differs in a value once you look closely — nvidia
# driver settings, pipewire shape, etc) stays in each host's own
# configuration.nix instead of being forced together here.
{ ... }:
{
  nix.settings.trusted-users = [ "root" "skver" ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;

  networking.nftables.enable = true;
  networking.firewall.enable = false;

  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both";
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];

  security.sudo.wheelNeedsPassword = false;

  services.xserver.videoDrivers = [ "nvidia" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
