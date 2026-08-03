{ config, inputs, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./docker.nix
      ./homepage.nix
      ./anubis.nix
      ./shares.nix
      ./backup.nix
      ./smart.nix
      ./vms.nix
      ./modules/gpuFanControl.nix
      ./modules/staticFanSpeed.nix
      ../../modules/sops.nix
      ../../modules/common.nix
    ];

  sops.defaultSopsFile = ../../secrets/yelena.yaml;

  hardware.gpuFanControl.enable = false;
  services.staticFanSpeed.enable = true;

  nixpkgs.config.nvidia.acceptLicense = true;

  # I WANNA IMPROVE MY PERFORMANCE OOOAAAAH
  boot.kernel.sysctl = {
    "vm.nr_hugepages" = 4096;
  };

  # avoid fragmentation??
  boot.kernelParams = [
    "hugepages=4096"
    "intel_iommu=on"
    "iommu=pt"
    "vfio-pci.ids=10de:15f8"
  ];

  services.vscode-server.enable = true;

  boot.extraModprobeConfig = ''
    blacklist nouveau
    options kvm_intel nested=1
  '';

  boot.kernelModules = [
    "k10temp"
    "nct6775"
    "ip_tables"
    "vfio"
    "vfio_pci"
    "vfio_iommu_type1"
    "vfio_virqfd"
  ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    # 16.5 -> working, but bsod in windows
    # 17.3 -> todo, works with 1080, not p100
  };

  hardware.graphics = {
    enable = true;
  };

  networking.hostName = "yelena"; # Define your hostname.

  time.timeZone = "Europe/Budapest";

#  console = {
#    keyMap = "hu";
#  };

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

