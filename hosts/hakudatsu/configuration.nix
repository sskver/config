# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ../../modules/nixos.nix
    ];

  nix.buildMachines = [
    {
      hostName = "zseton";
      sshUser = "skver";
      system = "x86_64-linux";
      maxJobs = 8; # or whatever your server can handle
      speedFactor = 2; # higher = preferred
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" ];
    }
  ];

  nix.settings.trusted-users = [ "root" "skver" ];
  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;


  nix.settings = {
    substituters = ["https://nix-gaming.cachix.org" "https://ezkea.cachix.org" "https://cache.nixos-cuda.org"];
    trusted-public-keys = ["nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI=" "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="];
  };

  services.usbmuxd.enable = true;
  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = "powersave";
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "hakudatsu"; # Define your hostname.

  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Budapest";

  services.printing.enable = true;

#  services.xserver.libinput.enable = true;
#  services.xserver.libinput.touchpad.naturalScrolling = true;
 
  programs.fish.enable = true;
  
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    config.common.default = [ "kde" ];
  };


# Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.skver = {
    shell = pkgs.fish;
    isNormalUser = true;
    description = "skver";
    extraGroups = [ "input" "networkmanager" "wheel" "docker" "video" ];
    packages = with pkgs; [
      firefox
#      kitty
#      thunderbird
    ];
  };

  environment.systemPackages = with pkgs; [
     #libimobiledevice
     wget
     git
  #   p7zip
     fprintd
     #python311
     #sage
     brightnessctl
     #hyprpaper
     #wlr-randr
     #nwg-displays
     #swaylock
     #rpi-imager
     #pavucontrol
     htop
     glib
     #dracula-theme
     #gnome.adwaita-icon-theme
     xdg-utils
     #configure-gtk
     #gnome.nautilus
     #gnome.eog
     #wineWowPackages.waylandFull
     #winetricks
     #php
  ];

  services.fprintd = {
    enable = true;
    package = pkgs.fprintd;
  };

  networking.firewall = {
    allowedUDPPorts = [ 51820 ];
  };

  system.stateVersion = "23.05"; # Did you read the comment? :)
}
