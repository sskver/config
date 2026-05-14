# until this is merged: https://github.com/NixOS/nixpkgs/pull/519117

{ config, lib, pkgs, ... }:

let
  gpuScreenRecorderUiPkg =
    pkgs.callPackage
      ({ lib
       , stdenv
       , fetchgit
       , pkg-config
       , meson
       , ninja
       , makeWrapper
       , gpu-screen-recorder
       , gpu-screen-recorder-notification
       , libx11
       , libxrender
       , libxrandr
       , libxcomposite
       , libxi
       , libxcursor
       , libglvnd
       , libpulseaudio
       , libdrm
       , dbus
       , wayland
       , wayland-scanner
       , wrapperDir ? "/run/wrappers/bin"
       , gitUpdater
       }:

        stdenv.mkDerivation (finalAttrs: {
          pname = "gpu-screen-recorder-ui";
          version = "1.10.8";

          src = fetchgit {
            url = "https://repo.dec05eba.com/gpu-screen-recorder-ui";
            tag = finalAttrs.version;
            hash = "sha256-x7MBTUWDKCzClq4ukgtFazOD/RLkX5lgmm9slN5BjVk=";
          };

          patches = [
            ./remove-gnome-postinstall.patch
          ];

          postPatch = ''
            substituteInPlace depends/mglpp/depends/mgl/src/gl.c \
              --replace-fail "libGL.so.1" "${lib.getLib libglvnd}/lib/libGL.so.1" \
              --replace-fail "libGLX.so.0" "${lib.getLib libglvnd}/lib/libGLX.so.0" \
              --replace-fail "libEGL.so.1" "${lib.getLib libglvnd}/lib/libEGL.so.1"

            substituteInPlace extra/gpu-screen-recorder-ui.service \
              --replace-fail "ExecStart=gsr-ui" "ExecStart=$out/bin/gsr-ui"

            substituteInPlace gpu-screen-recorder.desktop \
              --replace-fail "Exec=gsr-ui" "Exec=$out/bin/gsr-ui"
          '';

          nativeBuildInputs = [
            pkg-config
            meson
            ninja
            makeWrapper
          ];

          buildInputs = [
            libx11
            libxrender
            libxrandr
            libxcomposite
            libxi
            libxcursor
            libglvnd
            libpulseaudio
            libdrm
            dbus
            wayland
            wayland-scanner
          ];

          mesonFlags = [
            (lib.mesonBool "capabilities" false)
          ];

          postInstall =
            let
              gpu-screen-recorder-wrapped = gpu-screen-recorder.override {
                inherit wrapperDir;
              };
            in
            ''
              wrapProgram "$out/bin/gsr-ui" \
                --prefix PATH : "${wrapperDir}" \
                --suffix PATH : "${
                  lib.makeBinPath [
                    gpu-screen-recorder-wrapped
                    gpu-screen-recorder-notification
                  ]
                }"
            '';

          passthru.updateScript = gitUpdater { };

          meta = {
            description = "Fullscreen overlay UI for GPU Screen Recorder in the style of ShadowPlay";
            homepage = "https://git.dec05eba.com/gpu-screen-recorder-ui/about/";
            license = lib.licenses.gpl3Only;
            mainProgram = "gsr-ui";
            maintainers = with lib.maintainers; [ js6pak ];
            platforms = lib.platforms.linux;
          };
        }))
      { };

  cfg = config.programs.gpu-screen-recorder-ui;

in
{
  options.programs.gpu-screen-recorder-ui.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to install gpu-screen-recorder-ui and generate setcap wrappers for global hotkeys.";
  };

  config = lib.mkIf cfg.enable {

    programs.gpu-screen-recorder.enable = lib.mkDefault true;

    environment.systemPackages = [
      gpuScreenRecorderUiPkg
    ];

    systemd.packages = [
      gpuScreenRecorderUiPkg
    ];

    security.wrappers."gsr-global-hotkeys" = {
      owner = "root";
      group = "root";
      capabilities = "cap_setuid+ep";
      source = lib.getExe' gpuScreenRecorderUiPkg "gsr-global-hotkeys";
    };

  };
}