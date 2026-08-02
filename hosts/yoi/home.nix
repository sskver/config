{ config, pkgs, inputs, ... }:
{
  imports = [
    inputs.hyprcursor-phinger.homeManagerModules.hyprcursor-phinger
    inputs.nixcord.homeModules.nixcord
  ];

  home.username = "skver";
  home.homeDirectory = "/home/skver";
  
  home.stateVersion = "23.05"; 
  home.packages = with pkgs; [
    easyeffects
    openrgb
    uv
    blender 
    claude-code
    nixd
    nil
    wine-staging
    gcc
    zed-editor
    go
    gopls
    golangci-lint
    crosspipe
    grim
    slurp
    wl-clipboard
    waybar
    hyprpaper
    pywal
    vscode
    audacity
    prismlauncher
    lutris
    vial
    sshfs
    pavucontrol
    yt-dlp
    obs-studio
    steam-run
    pfetch
    rpi-imager
    mangohud
    any-nix-shell
    kdePackages.ark
    obsidian
    xivlauncher
    slack
    uxplay
    inputs.zen-browser.packages."${system}".default
    brave
    remmina
    xrandr
    solaar
    deskflow
    vulkan-tools
    virt-manager
    moonlight-qt
    losslesscut-bin
    inputs.nix-gaming.packages."${system}".osu-lazer-bin
    spotify
    wootility
  ];

  programs.nixcord = {
    enable = true;
    openASAR.enable = false;
    discord.equicord.enable = true;
    discord.branch = "canary";
    config.plugins = {
      crashHandler = {
        enable = true;
        attemptToPreventCrashes = true;
        attemptToNavigateToHome = false;
      };

      experiments = {
        enable = true;
        toolbarDevMenu = false;
      };

      fixImagesQuality = {
        enable = true;
        originalImagesInChat = false;
      };

      fixSpotifyEmbeds = {
        enable = true;
      };

      imageZoom = {
        enable = true;
      };

      LastFMRichPresence = {
        enable = true;
        shareUsername = true;
        hideWithSpotify = true;
        statusName = "some music";
        nameFormat = "status-name";
        useListeningStatus = false;
        missingArt = "logo";
        username = "skver0";
        apiKey = "a36c1ce0a44a02d62d688ddaf66ef14d"; # revoked btw, lmao, stupid moment
        showLogo = true;
        hideWithActivity = false;
        statusDisplayType = "off";
        clickableLinks = true;
        showAlbumCover = true;
      };

      messageLogger = {
        enable = true;
        deleteStyle = "text";
        ignoreBots = false;
        ignoreSelf = false;
        ignoreUsers = "";
        ignoreChannels = "";
        ignoreGuilds = "";
        logEdits = true;
        logDeletes = true;
        collapseDeleted = false;
        inlineEdits = true;
      };

      noBlockedMessages = {
        enable = true;
        ignoreMessages = false;
        applyToIgnoredUsers = true;
      };

      openInApp = {
        enable = true;
        spotify = true;
        steam = true;
        epic = true;
        tidal = true;
        itunes = true;
      };

      platformIndicators = {
        enable = true;
        colorMobileIndicator = true;
        list = true;
        badges = true;
        messages = true;
      };

      relationshipNotifier = {
        enable = true;
        offlineRemovals = true;
        groups = true;
        servers = true;
        friends = true;
        friendRequestCancels = true;
        notices = false;
      };

      reverseImageSearch = {
        enable = true;
      };

      translate = {
        enable = true;
        service = "google";
        deeplApiKey = "";
        autoTranslate = false;
        showAutoTranslateTooltip = true;
        receivedInput = "auto";
        receivedOutput = "en";
        sentInput = "auto";
        sentOutput = "en";
      };

      typingIndicator = {
        enable = true;
        includeMutedChannels = false;
        includeCurrentChannel = true;
        indicatorMode = 3;
        includeBlockedUsers = false;
      };

      webContextMenus = {
        enable = true;
        addBack = true;
      };

      webKeybinds = {
        enable = true;
      };

      fixYoutubeEmbeds = {
        enable = true;
      };

      betterSettings = {
        enable = true;
        disableFade = true;
        eagerLoad = true;
        organizeMenu = true;
      };

      implicitRelationships = {
        enable = true;
        sortByAffinity = true;
      };

      replyTimestamp = {
        enable = true;
      };

      webScreenShareFixes = {
        enable = true;
      };

      youtubeAdblock = {
        enable = true;
      };

      disableDeepLinks = {
        enable = true;
      };
    };

  };

  programs.hyprcursor-phinger.enable = true;

  home.file = {
    ".config/hypr".source = ../../home/hypr;
    ".config/waybar".source = ../../home/waybar;
  };

  xdg.enable = true;
  xdg.mime.enable = true;
  
  programs.home-manager.enable = true;
}
