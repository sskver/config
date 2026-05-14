{ config, pkgs, ... }:
{
 environment.systemPackages = with pkgs; [
#    dunst
    cifs-utils
#    virt-manager
    glib
    alsa-utils
    gnupg
    wget
    zip
#    alacritty
#    rofi-wayland
#    gnome-keyring
#    eog
    htop
    killall
    zip
    unzip
    rar
    unrar
    p7zip
    ffmpeg
    mpv
    #wineWow64Packages.staging
    winetricks
#    lxappearance
    git
#    qemu_kvm
    qjackctl
    shared-mime-info
    xdg-utils
    protonplus
    lsof
    pciutils
    scrot
    ns-usbloader
    lm_sensors
    gamescope
    virt-viewer
    egl-wayland
    cage
    waydroid-helper
  ];
}
