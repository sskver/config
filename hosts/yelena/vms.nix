{ config, lib, pkgs, ... }:
/*let
  patchScript = pkgs.writeScript "patch-qemu.py" (builtins.readFile ./patches/patch-qemu.py);
  logoFile = builtins.path { 
    path = ./patches/Logo.bmp; 
    name = "Logo.bmp"; 
  };

  ovmfPatched =
    pkgs.OVMF.overrideAttrs (attrs: {
      postPatch = (attrs.postPatch or "") + ''
        echo "Running OVMF patch..."
        #${pkgs.python3}/bin/python3 ${patchScript} . --patch-edk2

        if [ -f MdeModulePkg/Logo/Logo.bmp ]; then
          echo "Replacing EDK2 logo..."
          cp ${logoFile} MdeModulePkg/Logo/Logo.bmp
        fi
      '';
    });
  ovmfPatchedFd = ovmfPatched.fd;
in*/
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true;
      /*package = pkgs.qemu_kvm.overrideAttrs (attrs: {
        hostCpuOnly = true;
        postPatch = (attrs.postPatch or "") + ''
          echo "Running QEMU patch script..."
          ${pkgs.python3}/bin/python3 ${patchScript} .
          ${pkgs.python3}/bin/python3 ${patchScript} . --replace-vendor-id
        '';
      });*/
    };
  };

  environment.systemPackages = with pkgs; [
#    ovmfPatched
  ];
/*
  environment.etc = {
    "ovmf/edk2-x86_64-secure-code.fd" = {
      source = config.virtualisation.libvirtd.qemu.package + "/share/qemu/edk2-x86_64-secure-code.fd";
    };

    "ovmf/edk2-i386-vars.fd" = {
      source = config.virtualisation.libvirtd.qemu.package + "/share/qemu/edk2-i386-vars.fd";
    };

    "ovmf/edk2-x86_64-secure-code-vendored.fd" = {
      source = ovmfPatchedFd + "/FV/OVMF_CODE.fd";
    };
    "ovmf/edk2-x86_64-vars-vendored.fd" = {
      source = ovmfPatchedFd + "/FV/OVMF_VARS.fd";
    };
  };
 */
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
