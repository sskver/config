{ config, inputs, lib, pkgs, ... }:

let
  # Single forced-command target for the `deploy` CI user. Each pipeline SSHes
  # in passing the service short-name as its command (appleboy/ssh-action
  # `script:`), which arrives as $SSH_ORIGINAL_COMMAND. Anything outside the
  # allowlist is refused, so one key safely restarts several containers.
  deployDispatch = pkgs.writeShellScript "deploy-dispatch" ''
    set -eu
    svc="''${SSH_ORIGINAL_COMMAND:-}"
    case "$svc" in
      skverspace|kanade)
        exec sudo /run/current-system/sw/bin/systemctl restart "docker-$svc" ;;
      *)
        echo "deploy-dispatch: refusing to run '$svc'" >&2
        exit 1 ;;
    esac
  '';
in
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
      ./modules/cpuFanCurve.nix
      ../../modules/sops.nix
      ../../modules/common.nix
    ];

  sops.defaultSopsFile = ../../secrets/yelena.yaml;

  # V100 blower follows the HBM temperature: slow when idle, 100% from ~78C (measured: at 69% the
  # HBM hits 85C in 63s and decode drops ~20%, so under load it needs full speed)
  hardware.gpuFanControl = {
    enable = true;
    sensor = "memory";
    gpuName = "Tesla V100";
    minTemp = 50;
    maxTemp = 78;
    minPwm = 70;
    maxPwm = 255;
  };
  services.staticFanSpeed.enable = false;

  # quieter CPU fan (pwm2): 25% at 30C, 35% at 40C, 55% at 50C, 100% from 60C
  services.cpuFanCurve.enable = true;

  nixpkgs.config.nvidia.acceptLicense = true;

  # (no hugepages reserved: 8 GiB sat unused with no VM defined, and RAM is what the local LLM needs)
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "vfio-pci.ids=10de:15f8"
    # the ARC defaulted to ~all RAM (77 GB) and gave memory back too slowly: a big local-LLM run
    # thrashed the box into hung tasks (2026-10-02). 16 GiB is plenty for the pool.
    "zfs.zfs_arc_max=17179869184"
  ];

  # kill the biggest offender early instead of letting the box thrash (the kernel OOM killer never fired).
  # swap threshold 100 = act on low RAM alone: the thrash here is mostly file-backed pages (mapped model files), so swap
  # barely fills and a "swap <= 50% free" condition never fired in the second freeze (2026-10-02).
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 6;
    freeSwapThreshold = 100;
    extraArgs = [
      "--avoid" "(^|/)(systemd|sshd|dockerd|containerd|zed|zfs)$"
      "--prefer" "(^|/)(strata|ncu|ncu-ui)$"
    ];
  };

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
      ''command="${deployDispatch}",no-port-forwarding,no-agent-forwarding,no-x11-forwarding,no-pty ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFK9fFnQJ75+U11NJKU8RY1Z+ObdqyRD/wjtoioLkp+Y forgejo-ci''
    ];
  };

  security.sudo.extraRules = [{
    users = [ "deploy" ];
    commands = [
      {
        command = "/run/current-system/sw/bin/systemctl restart docker-skverspace";
        options = [ "NOPASSWD" ];
      }
      {
        command = "/run/current-system/sw/bin/systemctl restart docker-kanade";
        options = [ "NOPASSWD" ];
      }
    ];
  }];

  system.stateVersion = "24.05"; # Did you read the comment?, no i didnt
}
