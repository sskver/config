{ config, pkgs, inputs, ... }:
{
  imports = [
    #../../modules/emacs.nix
    inputs.hyprcursor-phinger.homeManagerModules.hyprcursor-phinger
  ];

  home.username = "skver";
  home.homeDirectory = "/home/skver";
  
  home.stateVersion = "23.05"; 
  home.packages = with pkgs; [
 #   grim
 #   slurp
 #   wl-clipboard
 #   waybar
 #   hyprpaper
 #   pywal
    vscode
    audacity
    prismlauncher
    lutris
    vial
    sshfs
    pavucontrol
    yt-dlp
    obs-studio
    steam-run
    pfetch
    rpi-imager
    mangohud
    any-nix-shell
    kdePackages.ark
    nodejs
    #gpu-screen-recorder-gtk
    obsidian
    xivlauncher
    slack
    uxplay
    inputs.zen-browser.packages."${system}".default
    chromium
    brave
  #  (import ./../../modules/byar.nix { pkgs = pkgs; })
    remmina
    xorg.xrandr
    solaar
 #   lsfg-vk-ui
    deskflow
    vulkan-tools
    virt-manager
    moonlight-qt
    discord
    losslesscut-bin
    vesktop
    inputs.nix-gaming.packages."${system}".osu-lazer-bin
#    inputs.nix-gaming.packages.${pkgs.stdenv.hostPlatform.system}.osu-stable
    spotify
    wootility
    pnpm
  ];

 # programs.hyprcursor-phinger.enable = true;
 /* 
  programs.hyprlock = {
    enable = false;
  };

  services.hypridle.enable = false;
  
/*  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };

    gtk3.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };

    gtk4.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
    
  };
*/  
  home.file = {
#    ".config/i3".source = ../../home/i3;
#    ".config/polybar".source = ../../home/polybar;
#    ".config/rofi".source = ../../home/rofi;
#    ".config/alacritty".source = ../../home/alacritty;
#    ".config/hypr".source = ../../home/hypr;
#    ".config/waybar".source = ../../home/waybar;
  };

  xdg.enable = true;
  xdg.mime.enable = true;
  
  programs.home-manager.enable = true;
}
