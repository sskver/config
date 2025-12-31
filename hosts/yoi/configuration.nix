{ config, lib, pkgs, inputs, ... }: 
{
  imports =
    [
      ./hardware-configuration.nix
      ./system-packages.nix
      ../../modules/nixos.nix
      inputs.spicetify-nix.nixosModules.default
      ../../modules/gpu-screen-recorder-ui.nix
    ];

  nixpkgs.overlays = [
    (final: prev: {
      klassy = final.callPackage ../../modules/klassy.nix { };
    })
    (final: prev: {
      gpu-screen-recorder-notification = final.callPackage ../../modules/gpu-screen-recorder-notification.nix { };
    })
    (final: prev: {
      discord = prev.discord.override {
        withOpenASAR = true;
        withVencord = true;
      };
    })
  ];

  nix.settings = {
    substituters = ["https://nix-gaming.cachix.org" "https://ezkea.cachix.org"];
    trusted-public-keys = ["nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI="];
  };

  hardware = {
    nvidia-container-toolkit = {
      enable = true;
      mount-nvidia-executables = false;
    };

    cpu.amd.updateMicrocode = true;

    graphics = {
      enable = true;
      extraPackages = with pkgs; [
         nvidia-vaapi-driver
         egl-wayland
      ];
      enable32Bit = true;
    };

    nvidia = {
      modesetting.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
      open = true;
    };

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    keyboard.qmk.enable = true;
    logitech.wireless.enable = true;
  };

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 2;
      };
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "ntfs" ];  
    kernelPackages = pkgs.linuxPackages_zen;
    kernelModules = [ "i2c-dev" "i2c-piix4" "vfio-pci" "vfio" "vfio_iommu_type1" "vfio_virqfd" "nvidia_uvm" ];
    kernelParams = [ "nvidia_drm.fbdev=1" "nvidia_drm.modeset=1" "amd_iommu=on" "kvm-amd.avic=1" "kvm_amd.nested=1" "kvm_amd.sev=1" "acpi_enforce_resources=lax" "pcie_acs_override=downstream,multifunction" "quiet" "udev.log_level=0" ];
    tmp.cleanOnBoot = true;
    extraModprobeConfig = "options vfio-pci ids=10de:0e22,10de:0beb";
  };

  security = {
    sudo.wheelNeedsPassword = false;
    polkit.enable = true;
  };

  virtualisation.docker.enable = true;

  services = {
    dbus.enable = true;

    gnome = {
      gnome-keyring.enable = true;
      at-spi2-core.enable = true;
    };

    displayManager.sddm.enable = true;

    desktopManager.plasma6.enable = true;

    udev.packages = with pkgs; [
      via
      openrgb
      logitech-udev-rules
    ];

    xserver.videoDrivers = ["nvidia"];

    #blueman.enable = true;

    avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
        userServices = true;
      };
    };

  };

  programs = {

    steam = {
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      enable = true;
    };

    adb.enable = true;

    nix-ld.enable = true;

    spicetify = {
      enable = true;
      alwaysEnableDevTools = true;
      enabledExtensions = [
        inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system}.extensions.adblockify
        inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system}.extensions.hidePodcasts
        ({
          src = (pkgs.fetchFromGitHub {
            owner = "BlafKing";
            repo = "spicetify-cat-jam-synced";
            rev = "e7bfd49fcc13457bbc98e696294cf5cf43eb6c31";
            hash = "sha256-pyYa5i/gmf01dkEF9I2awrTGLqkAjV9edJBsThdFRv8=";
          }) + /marketplace;
          name = "cat-jam.js";
        })
      ];
      theme = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system}.themes.catppuccin;
      colorScheme = "mocha";
    };

    fish.enable = true;

    gpu-screen-recorder = {
      enable = true;
    };

    gpu-screen-recorder-ui.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    config.common.default = [ "kde" ];
  };

  networking = {
    firewall.enable = false;
    hostName = "yoi";
    networkmanager.enable = true;
  };

  time.timeZone = "Europe/Budapest";

  fileSystems = {
    "/" = {
      options = [ "subvol=@" "compress=zstd" ];
    };
    "/home" = {
      options = [ "subvol=@home" "compress=zstd" ];
    };
    "/nix" = {
      options = [ "subvol=@nix" "compress=zstd" "noatime" ];
    };
    "/games" = {
      options = [ "subvol=@games" "compress=zstd:3" "noatime" ];
    };
    "/swap" = {
      options = [ "subvol=@swap" "noatime" ];
    };
    "/mnt/share" = {
      device = "//192.168.0.104/pool";
      fsType = "cifs";
      options = let
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,gid=1000,uid=1000";
      in ["${automount_opts},credentials=/smb-secrets"];
    };
  };

  users = {
    users.skver = {
      isNormalUser = true;
      extraGroups = [ "networkmanager" "adbusers" "libvirtd" "cdrom" "wheel" "audio" "jackaudio" "docker" "video" "input" ];
      shell = pkgs.fish; 
    };
  };

  environment = {
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
    systemPackages = with pkgs; 
    [ 
      klassy 
      gpu-screen-recorder-notification   
      kdePackages.breeze-icons
      kdePackages.breeze-gtk
    ];
  };


 # qt.platformTheme = "qt5ct";

  system.stateVersion = "22.11"; # Did you read the comment? yes, dont change this value unless you know what you are doing
}

