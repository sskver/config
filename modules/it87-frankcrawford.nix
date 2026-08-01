{ pkgs, lib, stdenv, fetchFromGitHub, kernel }:

stdenv.mkDerivation {
  pname = "it87-frankcrawford";
  version = "git";

  src = fetchFromGitHub {
    owner = "frankcrawford";
    repo = "it87";
    rev = "20f2f2f4c92c14fcdd26f60d050e693ad2c30bf8";
    sha256 = "sha256-iWyOctK+TFhVCOw2LiV4NiNFEAqNXOpSdGY//VwO8Ko=";
  };

  nativeBuildInputs = [ kernel.dev ] ++ kernel.moduleBuildDependencies;

  buildPhase = ''
    make clean modules KERNEL_BUILD=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
  '';

  installPhase = ''
    mkdir -p $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/hwmon
    cp it87.ko $out/lib/modules/${kernel.modDirVersion}/kernel/drivers/hwmon/
  '';

  meta = with lib; {
    description = "Custom it87 kernel module at specific commit";
    license = licenses.gpl2;
    platforms = platforms.linux;
  };
}
