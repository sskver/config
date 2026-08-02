{ config, inputs, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./docker.nix
      ./shares.nix
      ./backup.nix
      ./smart.nix
      ./vms.nix
      ./modules/gpuFanControl.nix
      ./modules/smartWebhook.nix
      ../../modules/sops.nix
    ];

  sops.defaultSopsFile = ../../secrets/yelena.yaml;

  nix.settings.trusted-users = [ "root" "skver" ];

  # enable gpu fan control
  hardware.gpuFanControl.enable = false;

  # force fan speeds:
  systemd.services.set-nct-fan-speed = {
    description = "Configure NCT6775 Fan Speed";
    
    # The script to run. We add a small loop to wait for the sysfs files 
    # to appear, ensuring hardware is ready before writing.
    script = ''
      PATH=$PATH:/run/current-system/sw/bin
      
      # Wait until the pwm file exists (in case driver loads late)
      while [ ! -f /sys/devices/platform/nct6775.2592/hwmon/hwmon1/pwm1_enable ]; do
        sleep 0.2
      done

      echo 1 > /sys/devices/platform/nct6775.2592/hwmon/hwmon1/pwm1_enable
      echo 70 > /sys/devices/platform/nct6775.2592/hwmon/hwmon1/pwm1
    '';

    # Run this after basic system initialization and multi-user boot target
    wantedBy = [ "multi-user.target" ];
    
    # Ensure it runs after local filesystems are mounted
    before = [ "local-fs.target" ]; 
  };

  nixpkgs.config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
    cudaSupport = true;
  };

  # scale my tail

  services.tailscale.enable = true;
  networking.nftables.enable = true;

  services.tailscale.useRoutingFeatures = "both";

  systemd.services.tailscaled.serviceConfig.Environment = [ 
    "TS_DEBUG_FIREWALL_MODE=nftables" 
  ];


#  environment.etc."issue".text = ''
#\e[1;36mZSETON\e[0m :: \e[1;31mscrap infrastructure\e[0m \e[1;33morchestrator\e[0m :: SIO TM
#--------------------------------------------------------------------------------
#
#hostname  : \n
#kernel    : \r
#time      : \t
#
#login is on you.
#'';

  # I WANNA IMPROVE MY PERFORMANCE OOOAAAAH
  boot.kernel.sysctl = {
    "vm.nr_hugepages" = 4096;
  };

  # avoid fragmentation??
  boot.kernelParams = [ 
    "hugepages=4096"
#    "nvidia.vup_swrlwar=1"
    "intel_iommu=on"
    "iommu=pt"
    "vfio-pci.ids=10de:15f8"
  ];

  # iptables rules for routing LAN traffic to VPN
  # and vice versa
#  networking.firewall.extraCommands = ''
    # NAT LAN -> VPN
#    iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -d 10.8.0.0/24 -j MASQUERADE
    # forwarding....
#    iptables -A FORWARD -s 192.168.0.0/24 -d 10.8.0.0/24 -j ACCEPT
#    iptables -A FORWARD -s 10.8.0.0/24 -d 192.168.0.0/24 -j ACCEPT
#  '';

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.vscode-server.enable = true;

  boot.extraModprobeConfig = ''
    blacklist nouveau
    options kvm_intel nested=1
#    options it87 ignore_resource_conflict=1 force_id=0x8622
  '';

  boot.kernelModules = [ 
    "k10temp" "nct6775" "ip_tables"
  "vfio"
  "vfio_pci"
  "vfio_iommu_type1"
  "vfio_virqfd"
#"coretemp" "it87" ]; 
  ];

  # I LOVE NVIDIA AND THEIR SHITTY DRIVERS
#  boot.kernelPackages = pkgs.linuxPackages_6_6;
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
#config.boot.kernelPackages.nvidiaPackages.latest;
#    package = config.boot.kernelPackages.nvidiaPackages.vgpu_16_5;
    #datacenter.enable = true;
    #package = config.boot.kernelPackages.nvidiaPackages.dc;
    #config.boot.kernelPackages.nvidiaPackages.stable;
    # 16.5 -> working, but bsod in windows
    # 17.3 -> todo, works with 1080, not p100
  };

/*  

 programs.mdevctl.enable = true;
  #vcfgclone ${TARGET}/vgpuConfig.xml 0x1B38 0x0 0x1B80 0x0000
# hardware.nvidia.vgpu.patcher.copyVGPUProfiles (attrset; only for host) - additional vcfgclone lines (see VUP's README)

#    For example, {"AAAA:BBBB" = "CCCC:DDDD"} is the same as vcfgclone ${TARGET}/vgpuConfig.xml 0xCCCC 0xDDDD 0xAAAA 0xBBBB

/*
  hardware.nvidia.vgpu.patcher.options.remapP40ProfilesToV100D = true;

  hardware.nvidia.vgpu.patcher.copyVGPUProfiles = {
    "15F8:0000" = "1B38:0";
  };


*/
/*

  hardware.nvidia.vgpu.patcher.enable = true;

  hardware.nvidia.vgpu.patcher.profileOverrides = {
    "160" = {
      vramAllocation = 4096;
      heads = 1;
      display.width = 2560;
      display.height = 1440;
      framerateLimit = 0;
      enableCuda = true;
    };
  };
*/

  services.xserver.videoDrivers = ["nvidia"];

  hardware.graphics = {
    enable = true;
  };

  networking.hostName = "yelena"; # Define your hostname.

  time.timeZone = "Europe/Budapest";

  console = {
    keyMap = "hu";
  };

  programs.fish.enable = true;

  users.users.skver = {
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      edac-utils
      htop
      swtpm
      git
    ];
    shell = pkgs.fish;
  };

  security.sudo.wheelNeedsPassword = false;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
      smartmontools
      lm_sensors
      wget
      virtiofsd
  ];

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    ports = [ 2222 ];
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # we need this for kvm spice audio?? idk
  services = {
    pipewire = {
      enable = true;
      audio.enable = true;
      pulse.enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      jack.enable = true;
    };
  };

  hardware.rasdaemon.enable = true;

  users.groups.deploy = {};

  users.users.deploy = {
    isSystemUser = true;
    group = "deploy";
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [
      ''command="sudo systemctl restart docker-skverspace",no-port-forwarding,no-agent-forwarding,no-x11-forwarding,no-pty ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFK9fFnQJ75+U11NJKU8RY1Z+ObdqyRD/wjtoioLkp+Y forgejo-ci''
    ];
  };

  security.sudo.extraRules = [{
    users = [ "deploy" ];
    commands = [{
      command = "/run/current-system/sw/bin/systemctl restart docker-skverspace";
      options = [ "NOPASSWD" ];
    }];
  }];

  system.stateVersion = "24.05"; # Did you read the comment?, no i didnt
}

