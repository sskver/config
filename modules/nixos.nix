{ config, pkgs, lib, inputs, ... }:
{
  imports = [ ./common.nix ];

  services.fstrim.enable = true;
  fonts.fontconfig.allowBitmaps = true;
  fonts.fontconfig.enable = true;
  fonts.packages = with pkgs; [
    font-awesome
    dina-font
    terminus_font
    corefonts
    jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    siji
    creep
    corefonts
  ];

  system.autoUpgrade = {
    enable = true;
    flake = inputs.self.outPath;
    flags = [
      "--recreate-lock-file"
      "--no-write-lock-file"
      "-L"
    ];
    dates = "daily";
  };

  networking.firewall.logRefusedConnections = false;
  xdg.mime.enable = true;

  nix.gc = {
   automatic = true;
   dates = "weekly";
   options = "--delete-older-than 10d";
  };

  # pipest wire, audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    socketActivation = true;
  };

  security.wrappers."mount.cifs" = {
    program = "mount.cifs";
    source = "${lib.getBin pkgs.cifs-utils}/bin/mount.cifs";
    owner = "root";
    group = "root";
    setuid = true;
  };
 
  services.btrfs.autoScrub.enable = true;
}
