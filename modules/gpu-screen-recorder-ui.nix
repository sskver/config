# https://github.com/NixOS/nixpkgs/pull/369574

{ config, lib, pkgs, ... }:

let
  gpuScreenRecorderUiPkg = pkgs.stdenv.mkDerivation rec {
    pname = "gpu-screen-recorder-ui";
    version = "1.8.3";

    src = pkgs.fetchgit {
      url = "https://repo.dec05eba.com/gpu-screen-recorder-ui";
      tag = version;
      hash = "sha256-KB4N5DwzPKYhqIi+IlvkS6ZRh3ByFPCfF75Hg+na7Q8=";
    };

    postPatch = ''
      substituteInPlace depends/mglpp/depends/mgl/src/gl.c \
        --replace-fail "libGL.so.1" "${lib.getLib pkgs.libglvnd}/lib/libGL.so.1" \
        --replace-fail "libGLX.so.0" "${lib.getLib pkgs.libglvnd}/lib/libGLX.so.0" \
        --replace-fail "libEGL.so.1" "${lib.getLib pkgs.libglvnd}/lib/libEGL.so.1"

      substituteInPlace extra/gpu-screen-recorder-ui.service \
        --replace-fail "ExecStart=gsr-ui" "ExecStart=$out/bin/gsr-ui"
    '';

    nativeBuildInputs = [ pkgs.pkg-config pkgs.meson pkgs.ninja pkgs.makeWrapper ];
    buildInputs = [
      pkgs.libx11
      pkgs.libxrender
      pkgs.libxrandr
      pkgs.libxcomposite
      pkgs.libxi
      pkgs.libxcursor
      pkgs.libglvnd
      pkgs.pulseaudio
      pkgs.libdrm
      pkgs.wayland
      pkgs.wayland-scanner
    ];

    mesonFlags = [ (lib.mesonBool "capabilities" false) ];

    postInstall =
      let
        gpuScreenRecorderWrapped = pkgs.gpu-screen-recorder.override { wrapperDir = "/run/wrappers/bin"; };
      in ''
        wrapProgram "$out/bin/gsr-ui" \
          --prefix PATH : "/run/wrappers/bin" \
          --suffix PATH : "${lib.makeBinPath [ gpuScreenRecorderWrapped pkgs.gpu-screen-recorder-notification ]}"
      '';

    meta = {
      description = "Fullscreen overlay UI for GPU Screen Recorder in the style of ShadowPlay";
      homepage = "https://git.dec05eba.com/gpu-screen-recorder-ui/about/";
      license = lib.licenses.gpl3Only;
      mainProgram = "gsr-ui";
      maintainers = with lib.maintainers; [ js6pak ];
      platforms = lib.platforms.linux;
    };
  };

  cfg = config.programs.gpu-screen-recorder-ui;
in
{
  options = {
    programs.gpu-screen-recorder-ui.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to install gpu-screen-recorder-ui and generate setcap wrappers for global hotkeys.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.gpu-screen-recorder.enable = lib.mkDefault true;

    environment.systemPackages = [ gpuScreenRecorderUiPkg ];

    systemd.packages = [ gpuScreenRecorderUiPkg ];

    security.wrappers."gsr-global-hotkeys" = {
      owner = "root";
      group = "root";
      capabilities = "cap_setuid+ep";
      source = lib.getExe' gpuScreenRecorderUiPkg "gsr-global-hotkeys";
    };
  };
}
