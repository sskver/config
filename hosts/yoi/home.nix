{ config, pkgs, inputs, ... }:
{
  imports = [
    #../../modules/emacs.nix
    inputs.hyprcursor-phinger.homeManagerModules.hyprcursor-phinger
    inputs.nixcord.homeModules.nixcord
  ];

  home.username = "skver";
  home.homeDirectory = "/home/skver";
  
  home.stateVersion = "23.05"; 
  home.packages = with pkgs; [
    thunderbird
    wine-staging
    gcc
    zed-editor
    go
    gopls
    golangci-lint
    crosspipe
 #   grim
 #   slurp
 #   wl-clipboard
 #   waybar
 #   hyprpaper
 #   pywal
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
    nodejs
    #gpu-screen-recorder-gtk
    obsidian
    xivlauncher
    slack
    uxplay
    inputs.zen-browser.packages."${system}".default
    chromium
    brave
  #  (import ./../../modules/byar.nix { pkgs = pkgs; })
    remmina
    xorg.xrandr
    solaar
 #   lsfg-vk-ui
    deskflow
    vulkan-tools
    virt-manager
    moonlight-qt
   # discord-canary
    losslesscut-bin
    vesktop
    inputs.nix-gaming.packages."${system}".osu-lazer-bin
#    inputs.nix-gaming.packages.${pkgs.stdenv.hostPlatform.system}.osu-stable
    spotify
    wootility
    pnpm
  ];

  programs.nixcord = {
    enable = true;
    discord.vencord.enable = true;
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

      favoriteGifSearch = {
        enable = true;
        searchOption = "url";
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
        missingArt = "lastfmLogo";
        username = "skver0";
        apiKey = "a36c1ce0a44a02d62d688ddaf66ef14d";
        showLastFmLogo = true;
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

      spotifyControls = {
        enable = true;
        hoverControls = false;
        useSpotifyUris = false;
        previousButtonRestartsTrack = true;
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

/*    userPlugins = {
      groupDms = "github:skver0/vencord-group-dms/d8df08cc1b3668cba7684dc1d291a12308177540";
    };
    extraConfig.plugins = {
      groupDms.enable = true;
    };*/
  };

 # programs.hyprcursor-phinger.enable = true;
 /* 
  programs.hyprlock = {
    enable = false;
  };

  services.hypridle.enable = false;
  
/*  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };

    gtk3.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };

    gtk4.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
    
  };
*/  
  home.file = {
#    ".config/i3".source = ../../home/i3;
#    ".config/polybar".source = ../../home/polybar;
#    ".config/rofi".source = ../../home/rofi;
#    ".config/alacritty".source = ../../home/alacritty;
#    ".config/hypr".source = ../../home/hypr;
#    ".config/waybar".source = ../../home/waybar;
  };

  xdg.enable = true;
  xdg.mime.enable = true;
  
  programs.home-manager.enable = true;
}
