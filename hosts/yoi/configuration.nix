{ config, lib, pkgs, inputs, ... }:
let
  it87-frankcrawford = pkgs.callPackage ../../modules/it87-frankcrawford.nix {
    kernel = config.boot.kernelPackages.kernel;
  };
in
{
  imports =
    [
      ./hardware-configuration.nix
      ./system-packages.nix
      ../../modules/nixos.nix
      inputs.spicetify-nix.nixosModules.default
#      ../../modules/gpu-screen-recorder-ui.nix
    ];

  nixpkgs.config.cudaSupport = false;


  boot.kernel.sysctl = {
    "net.ipv4.conf.ipv4_forward" = 1;
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;
  };

  networking.nftables = {
    enable = true;
  };


   systemd.services.tailscaled = {
    serviceConfig = {
      ExecStartPre = lib.mkBefore [
        (pkgs.writeShellScript "tailscaled-nft-start" ''
          ${pkgs.nftables}/bin/nft -f - <<'EOF'
          table inet mullvad-ts {
            chain outgoing {
              type route hook output priority 0; policy accept;
              ip daddr 100.64.0.0/10 ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
              ip6 daddr fd7a:115c:a1e0::/48 ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
            }

            chain incoming {
              type filter hook input priority -100; policy accept;
              iifname "tailscale0" ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
            }

            chain excludeDns {
              type filter hook output priority -10; policy accept;
              ip daddr 100.100.100.100 udp dport 53 ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
              ip daddr 100.100.100.100 tcp dport 53 ct mark set 0x00000f41 meta mark set 0x6d6f6c65;
            }
          }
          EOF
        '')
      ];

      ExecStopPost = lib.mkAfter [
        (pkgs.writeShellScript "tailscaled-nft-stop" ''
          ${pkgs.nftables}/bin/nft delete table inet mullvad-ts || true
        '')
      ];
    };
  };

  systemd.services.mullvad-daemon = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
  };

  nix.buildMachines = [
    {
      hostName = "yelena";
      sshUser = "skver";
      system = "x86_64-linux";
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" ];
    }
  ];

  nix.settings.trusted-users = [ "root" "skver" ];
  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;

#  networking.extraHosts =
#  ''
#  '';

  nixpkgs.overlays = [
 #   (final: prev: {
 #     gpu-screen-recorder-notification = final.callPackage ../../modules/gpu-screen-recorder-notification.nix { };
 #   })
#    (final: prev: {
#      discord-canary = prev.discord-canary.override {
#       # withOpenASAR = true;
#        withVencord = true;
#      };
#    })
  ];

  nix.settings = {
    substituters = ["https://nix-gaming.cachix.org" "https://ezkea.cachix.org" "https://cache.nixos-cuda.org" "https://cuda-maintainers.cachix.org"];
    trusted-public-keys = ["nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI=" "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=" "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="];
  };

  hardware = {
    uinput.enable = true;
    opentabletdriver = {
      enable = true;
      daemon.enable = true;
    };
    
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

  systemd.services.display-manager = {
    after = [ "systemd-udev-settle.service" ];
    wants = [ "systemd-udev-settle.service" ];
  };

  systemd.services.tailscaled.serviceConfig.Environment = [ 
    "TS_DEBUG_FIREWALL_MODE=nftables" 
  ];

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 2;
      };
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "ntfs" ];  

    extraModulePackages = [
      it87-frankcrawford
      config.boot.kernelPackages.zenergy
    ];
    blacklistedKernelModules = [ "wacom" ];
    
    kernelPackages = pkgs.linuxPackages_zen;
    kernelModules = [ 
        "i2c-dev" "i2c-piix4" "nvidia_uvm" 
        "it87"
        "zenergy"
        "uinput"
        #"vfio-pci" "vfio" "vfio_iommu_type1" "vfio_virqfd" 
      ];
    kernelParams = [ 
        "nvidia_drm.fbdev=1" 
        "simpledrm=0" 
        #"vfio-pci.ids=10de:2805,10de:22bd"
        "nvidia_drm.modeset=1"
        "amd_iommu=on" "kvm-amd.avic=1" "kvm_amd.nested=1" "kvm_amd.sev=1" 
        "acpi_enforce_resources=lax" 
        "pcie_acs_override=downstream,multifunction" 
      #"quiet" "udev.log_level=0" 
        "video=DP-3:2560x1440@180"
        "video=DP-2:1920x1080@144,rotate=90"
        #"mem_sleep_default=s2idle"
      ];
    tmp.cleanOnBoot = true;

    extraModprobeConfig = ''
      options it87 ignore_resource_conflict=1 force_id=0x8696
    '';
  };

  security = {
    sudo.wheelNeedsPassword = false;
    polkit.enable = true;
    polkit.enablePkexecWrapper = true;
  };

  virtualisation = {
    waydroid.enable = true;
    docker.enable = true;
    libvirtd = {
      enable = true;
      qemu = {
        #package = pkgs.qemu_kvm.overrideAttrs (attrs: {
        #  patches = attrs.patches or [] ++ [ ../../patches/qemu-hide-hypervisor-bit.patch ];
        #});
        runAsRoot = true;
        swtpm.enable = true;
      
       /*
        verbatimConfig = ''
          cgroup_device_acl = [
            "/dev/null", "/dev/full", "/dev/zero",
            "/dev/random", "/dev/urandom",
            "/dev/ptmx", "/dev/kvm", "/dev/nvidia0", "/dev/nvidiactl", "/dev/nvidia-modeset", "/dev/dri/renderD128"
          ]
          seccomp_sandbox = 0
        '';*/
        # P.S.: FUCK NVIDIA THE 12837839th TIME
      };
    };
  };

#  networking.nameservers = [ "100.100.100.100" ];
#  networking.search = [ "macaroni-escalator.ts.net" ];

  services = {
    resolved = {
      enable = true;
      settings.Resolve = {
        DNSSEC = "true";
        Domains = [ "~." ];
        DNSOverTLS = "true";
        FallbackDNS = [
          "1.1.1.1"
          "1.0.0.1"
        ];
      };
    };
    tailscale.enable = true;
    tailscale.useRoutingFeatures = "both";
    tailscale.extraUpFlags = [
       "--accept-dns=true"
       "--operator skver"
    ];

    mullvad-vpn = {
      enable = true;
      gui.enable = true;
    };
    dbus.enable = true;

    gnome = {
      gnome-keyring.enable = true;
      at-spi2-core.enable = true;
    };

    displayManager.sddm.enable = true;
    displayManager.sddm.wayland.enable = true;
    
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

   # gpu-screen-recorder = {
   #   enable = true;
   # };

   # gpu-screen-recorder-ui.enable = true;
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
      __GL_SHADER_DISK_CACHE_SIZE = "107374182404";
    };
    systemPackages = with pkgs; 
    [ 
     # gpu-screen-recorder-notification   
      kdePackages.breeze-icons
      kdePackages.breeze-gtk
    ];
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance";
  };

 # qt.platformTheme = "qt5ct";

  services.dbus.packages = [pkgs.gcr];
  programs.gnupg.agent = {
    enable = true;
  };
  
  system.stateVersion = "22.11"; # Did you read the comment? yes, dont change this value unless you know what you are doing
}

