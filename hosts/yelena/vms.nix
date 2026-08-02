{ config, lib, pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true;
    };
  };

  programs.virt-manager.enable = true;

  networking.interfaces.enp6s0.useDHCP = false;  
    networking.bridges = {
    "br0" = {
      interfaces = [ "enp6s0" ];
    };
  };

  networking.interfaces.br0.ipv4.addresses = [{
    address = "192.168.0.104";
    prefixLength = 24;
  }];

  networking.defaultGateway = "192.168.0.1";
  networking.nameservers = [ "192.168.0.104" "1.1.1.1" ];
}
