{ config, pkgs, inputs, ... }:
{
  imports = [
#    ../../modules/emacs.nix
#    ../../modules/discord.nix
  ];
  home.username = "skver";
  home.homeDirectory = "/home/skver";

  home.stateVersion = "23.05"; 
  home.packages = with pkgs; [
 #   (jetbrains.plugins.addPlugins jetbrains.idea-ultimate [ "github-copilot" ])
 #   jetbrains-toolbox
    vscode
    obsidian
    gimp
#    pavucontrol
 #   chromium
    spotify
    pfetch
 #   flameshot
 #   picom
 #   pywal
    rpi-imager
 #   texlive.combined.scheme-full
    ripgrep
    nodejs
    pnpm
 #   waybar
  #  rofi-wayland
  #  kanshi
  #  wl-clipboard
  #  slurp
  #  grim
    steam-run
  #  networkmanagerapplet
 #   alacritty
  ];
  home.file = {
#    ".config/i3".source = ../../home/i3;
#    ".config/polybar".source = ../../home/polybar;
#    ".config/rofi".source = ../../home/rofi;
 #   ".config/alacritty".source = ../../home/alacritty;
 #   ".config/hypr".source = ../../home/hypr;
 #   ".config/waybar".source = ../../home/waybar;
   };
  programs.home-manager.enable = true;
}
