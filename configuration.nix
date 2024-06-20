# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, programs, inputs, ... }:
#let
#  inochi-nixpkgs = import "/etc/nixos/inochi-nixpkgs" { };

#  inochi-nixpkgs = import inputs.nixpkgs-inochi {};
#let my-firefox-fix = import inputs.nixpkgs-my-firefox-patch {system = config.system;};
#in
let
  myClangStdenv = pkgs.stdenvAdapters.useMoldLinker
    (pkgs.stdenvAdapters.overrideCC pkgs.llvmPackages_18.stdenv
      (pkgs.llvmPackages_18.clang.override {
        bintools = pkgs.llvmPackages_18.bintools;
      }));
in {
  imports = [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./cachix.nix
  ];
  boot.tmp.useTmpfs = false; # webkit explodes this, firefox nearly does
  boot.tmp.cleanOnBoot = true; # old gcroots trash

  #  nixpkgs.config.replaceStdenv = pkgs.clangStdenv; # doesn't work

  nixpkgs.hostPlatform = {
    gcc.arch = "znver3";
    gcc.tune = "znver3";
    system = "x86_64-linux";
  };
  #  nixpkgs.buildPlatform = {
  #    gcc.arch = "znver3";
  #    gcc.tune = "znver3";
  #    system = "x86_64-linux";
  #  }; # this might be needed to unjank some builds # or it actually makes a different package fail..

  nixpkgs.config.permittedInsecurePackages = [ "nix-2.16.2" ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/efi";
  boot.supportedFilesystems = [ "ntfs" ];
  nix.settings.keep-derivations = true;
  nix.settings.keep-outputs = true;
  #  nix.settings.auto-optimise-store = true;
  nix.settings.trusted-users = [ "root" "wrath" ];
  nix.settings.cores = 8;
  nix.settings.max-jobs = 2;
  nix.settings.experimental-features =
    [ "nix-command" "flakes" "ca-derivations" ];
  nixpkgs.config.contentAddressedByDefault = true;
  nix.settings.allow-import-from-derivation = true;
  networking.hostName = "JustinMohnsIPod"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable =
    true; # Easiest to use and most distros use this by default.

  time.timeZone = "Europe/Amsterdam";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";
  console = {
    #   font = "Lat2-Terminus16";
    #     keyMap = "uk";
    useXkbConfig = true; # use xkb.options in tty.
  };
  fonts = {
    packages = with pkgs; [
      material-icons
      material-design-icons
      powerline-fonts
      terminus_font
      kawkab-mono-font
      roboto
      roboto-serif
      nika-fonts
      roboto-mono
      last-resort
      inconsolata
      lxgw-wenkai
      hack-font
      cantarell-fonts
      redhat-official-fonts
      source-han-mono
      source-han-sans
      source-han-serif
      corefonts
      dejavu_fonts
      freefont_ttf
      gyre-fonts # TrueType substitutes for standard PostScript fonts
      unifont
      noto-fonts-emoji
      liberation_ttf
      #  fira-code
      fira-code-symbols
      mplus-outline-fonts.githubRelease
      dina-font
      proggyfonts
      hachimarupop
      migmix
      ricty
      noto-fonts-extra
      noto-fonts
      samim-fonts
      sahel-fonts
      noto-fonts-monochrome-emoji
      noto-fonts-color-emoji
      twitter-color-emoji
      wqy_zenhei
      noto-fonts-cjk-serif
      noto-fonts-cjk-sans
      scheherazade-new
      noto-fonts-lgc-plus
      inconsolata-lgc
      doulos-sil
      source-sans-pro
      source-serif-pro
      nerdfonts # just use all of them..

    ];

    fontconfig.enable = true;
    fontDir.enable = true;
  };

  services.xserver.enable = true;
  #  services.displayManager.sddm.enable = true;

  #  services.xserver.desktopManager.plasma5.enable = true;
  #  services.xserver.desktopManager.plasma6.enable = true;
  services.desktopManager.plasma6.enable = true;
  #  services.xserver.displayManager.sx.enable = true;
  #  services.xserver.displayManager.defaultSession = "plasmax11";
  services.displayManager.defaultSession = "plasmax11";
  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-skk
      qt6Packages.fcitx5-qt
      #      fcitx5-mozc # broken download link, don't care enough to fix
      fcitx5-table-other
      fcitx5-chinese-addons
      fcitx5-configtool
      fcitx5-table-extra
    ];
  };

  services.xserver.xkb.layout = "gb";
  services.xserver.xkb.options = "compose:ralt";
  programs.gnupg.agent.pinentryPackage = pkgs.pinentry-qt;
  services.printing.enable = true;
  services.postfix.enable = true;
  services.smartd = {
    enable = true;
    notifications.mail = {
      enable = true;
      recipient = "wrath";

    };
  };

  #  sound.enable = true; # this is alsa
  #  hardware.pulseaudio.enable = true; # this is actual pulseaudio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    #jack.enable = true;
  };
  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  nixpkgs.overlays = [
    #                       (import "${inputs.nixpkgs-mozilla}/firefox-overlay.nix")
    (import "${inputs.fenix}/overlay.nix")
    (import inputs.emacs-overlay)
    (final_solution: prev:
      let
        pkgs = import inputs.nixpkgs { system = config.system; };
        noricingpkgs = import inputs.nixpkgs {
          localSystem = {
            system = "x86_64-linux";
            gcc = { };
          };
        };

      in {

        embree = noricingpkgs.embree;
        blender = noricingpkgs.blender;

      })

    (final: prev:
      let pkgs = import inputs.nixpkgs { system = config.system; };

      in {
        opencolorio = prev.opencolorio.overrideAttrs (attrs: {
          cmakeFlags = attrs.cmakeFlags ++ [ "-DOCIO_BUILD_TESTS=OFF" ];
        });

        inherit (rec {
          llvmPackages_18 = prev.recurseIntoAttrs (prev.callPackage
            "${inputs.nixpkgs}/pkgs/development/compilers/llvm/18" ({
              inherit (prev.stdenvAdapters) overrideCC;
              officialRelease = {
                version = "18.1.8";
                sha256 = "sha256-iiZKMRo/WxJaBXct9GdAcAT3cz9d9pnAcO1mmR6oPNE=";
              };
              buildLlvmTools = prev.buildPackages.llvmPackages_18.tools;
              targetLlvmLibraries =
                prev.targetPackages.llvmPackages_18.libraries or llvmPackages_18.libraries;
              targetLlvm =
                prev.targetPackages.llvmPackages_18.llvm or llvmPackages_18.llvm;
            }));

          clang_18 = llvmPackages_18.clang;
          lld_18 = llvmPackages_18.lld;
          lldb_18 = llvmPackages_18.lldb;
          llvm_18 = llvmPackages_18.llvm;

          clang-tools_18 = prev.callPackage
            "${inputs.nixpkgs}/pkgs/development/tools/clang-tools" {
              llvmPackages = llvmPackages_18;
            };
        })
          llvmPackages_18 clang_18 lld_18 lldb_18 llvm_18 clang-tools_18;

        mpv-unwrapped = prev.mpv-unwrapped.override {
          stdenv = myClangStdenv;
          rubberbandSupport = false;
        };
        mpv = final.mpv-unwrapped.wrapper { mpv = final.mpv-unwrapped; };

        umockdev = prev.umockdev.overrideAttrs (attrs: { doCheck = false; });
        tzdata = prev.tzdata.overrideAttrs (attrs: {
          doCheck = false;
          checkTarget = "";
        });
        haskellPackages = prev.haskellPackages.override {
          overrides = haskellSelf: haskellSuper: {
            x509-validation =
              final.haskell.lib.dontCheck haskellSuper.x509-validation;
            crypton-x509-validation =
              final.haskell.lib.dontCheck haskellSuper.crypton-x509-validation;
            cryptonite = final.haskell.lib.dontCheck haskellSuper.cryptonite;
          };
        };

        nethack = prev.nethack.overrideAttrs (oldattrs: {
          enableParallelBuilding = false;
        }); # it's a concurrent build bug actually
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (python-final: python-prev: {
            sphinx = python-prev.sphinx.overridePythonAttrs (oldAttrs: {
              disabledTests = oldAttrs.disabledTests ++ [
                "test_linkcheck_request_headers_default"
              ]; # stupid timeout failure on busy machine
            });
            mechanize = python-prev.mechanize.overridePythonAttrs (oldAttrs: {
              disabledTests = oldAttrs.disabledTests ++ [
                "test/test_urllib2.py::HandlerTests::test_ftp"
                "HandlerTests::test_ftp"
                "test_ftp"
              ];
            });
            numpy = python-prev.numpy.overridePythonAttrs (oldAttrs: {
              disabledTests = oldAttrs.disabledTests ++ [
                "test_umath_accuracy"
                "TestAccuracy::test_validate_transcendentals"
                "test_validate_transcendentals"
                "test_structured_object_item_setting"
                "TestStructuredObjectRefcounting::test_structured_object_item_setting"
              ];
            });
          })
        ];

      })

  ];

  zramSwap.enable = true;
  zramSwap.memoryPercent = 80;
  nixpkgs.config.allowUnfree = true;
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  users.users.root.initialHashedPassword = "";
  users.users.wrath = {
    uid = 1000;
    initialHashedPassword = "";
    isNormalUser = true;
    home = "/home/wrath";
    extraGroups = [ "wheel" "libvirtd" "adbusers" "nixseparatedebuginfod" ];
    packages = with pkgs;
      with inputs;
      #      let inochi-nixpkgs = import inputs.nixpkgs-inochi { inherit system; };
      #      in [
      [
        qt6ct
        ida-free
        pigz
        unrar
        p7zip
        np2kai
        mednaffe
        sx
        blender
        #        config.nur.repos.chigyutendies.suyu-dev
        config.nur.repos.chigyutendies.yuzu-early-access
        config.nur.repos.chigyutendies.citra-nightly
        inochi-session
        inochi-creator
        #        inochi-nixpkgs.inochi-session
        #        inochi-nixpkgs.inochi-creator
        gitAndTools.gh
        simplex-chat.packages.${system}."exe:simplex-chat"
        gluon_language-server.packages.${system}.onCrane
        android-studio
        gargoyle
        ffmpeg
        yt-dlp
        nethack
        #      adom # broken
        angband
        frotz
        netris
        sfrotz
        tintin
        scummvm
        calibre
        (pavucontrol.override { stdenv = myClangStdenv; })
        obs-studio
        telegram-desktop # too much of PITA to build with llvm
        ldtk
        (strawberry.override { stdenv = myClangStdenv; })
        yakuake
        (tree.override { stdenv = myClangStdenv; })
        (qbittorrent.override { stdenv = myClangStdenv; })
        (furnace.override { stdenv = myClangStdenv; })
        (nmap.override { stdenv = myClangStdenv; })
        #      chromium # nah
        (cmake.override { stdenv = myClangStdenv; })
        (element-desktop.override { stdenv = myClangStdenv; })
        fontforge
        (gimp.override { stdenv = myClangStdenv; })
        (lshw.override { stdenv = myClangStdenv; })
        #        libreoffice-qt
        inputs.nix-gaming.packages.${pkgs.hostPlatform.system}.wine-ge
        winetricks
        dxvk
        #        inputs.nix-gaming.packages.${system}.dxvk
        mpv
        lutris
        lyx
        #      vscode # I probably don't need this since I got gluon lsp working with emacs
      ];
  };
  services.emacs.enable = true;
  services.emacs.defaultEditor = true;
  #  services.emacs.package = pkgs.emacs-git;
  programs.firefox.enable = true;

  programs.firefox.package = pkgs.wrapFirefox
    (pkgs.firefox-devedition-unwrapped.override { stdenv = myClangStdenv; })
    { };

  programs.direnv.enable = true;
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  security.pam.loginLimits = [{
    domain = "*";
    type = "soft";
    item = "nofile";
    value = "65536";
  }];
  #services.tlp = {
  #  enable = true;
  #  settings = {
  #    CPU_DRIVER_OPMODE_ON_AC="active";
  #    CPU_DRIVER_OPMODE_ON_BAT="active";
  #    CPU_SCALING_GOVERNOR_ON_AC = "performance";
  #    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
  #    
  #    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
  #    CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
  #    CPU_HWP_DYN_BOOST_ON_AC=1;
  #    CPU_HWP_DYN_BOOST_ON_BAT=0;
  #    CPU_BOOST_ON_AC=1;
  #    CPU_BOOST_ON_BAT=0;
  #    CPU_MIN_PERF_ON_AC = 0;
  #    CPU_MAX_PERF_ON_AC = 100;
  #    CPU_MIN_PERF_ON_BAT = 0;
  #    CPU_MAX_PERF_ON_BAT = 20;

  #Optional helps save long term battery health
  #    START_CHARGE_THRESH_BAT0 = 40; # 40 and bellow it starts to charge
  #    STOP_CHARGE_THRESH_BAT0 = 80; # 80 and above it stops charging

  #  };
  #};
  programs.adb.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [
          (pkgs.OVMF.override {
            secureBoot = true;
            tpmSupport = true;
          }).fd
        ];
      };
    };
  };
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark-qt;
  };
  programs.virt-manager.enable = true;
  services.nixseparatedebuginfod.enable = true;
  #services.nixseparatedebuginfod.extra-allowed-users = [ "wrath" ];
  environment.systemPackages = with pkgs;
    let pkgs = import inputs.nixpkgs { system = config.system; };

    in [

      mercurial
      remmina
      ntfs3g
      woeusb-ng
      appimage-run
      file
      llvmPackages_18.bintools
      radare2
      retdec
      ctypes_sh
      tcpdump
      ghidra
      socat
      iaito
      unzip
      gdb
      valgrind
      elfutils
      gist
      jq
      filelight
      clasp
      angle-grinder
      xclip
      inputs.hnix.defaultPackage.x86_64-linux
      niv
      nixfmt-classic
      wgetpaste
      binwalk
      w3m
      (clang-tools.override { llvmPackages = llvmPackages_18; })
      (bat.override { stdenv = myClangStdenv; })
      nix-tree
      nix-du
      nix-diff
      smartmontools
      lm_sensors
      neomutt
      nixd
      nil
      (lynx.override { stdenv = myClangStdenv; })
      (tmux.override { stdenv = myClangStdenv; })
      (htop.override { stdenv = myClangStdenv; })
      (btop.override { stdenv = myClangStdenv; })
      nvtopPackages.full
      (iftop.override { stdenv = myClangStdenv; })
      (ripgrep.override {
        withPCRE2 = true;
        stdenv = myClangStdenv;
      })
      (gnutls.override { stdenv = myClangStdenv; }) # for TLS connectivity
      fd
      imagemagick
      sysstat
      (zstd.override {
        stdenv = myClangStdenv;
      }) # for undo-fu-session/undo-tree compression
      # :tools lookup & :lang org +roam
      (sqlite.override { stdenv = myClangStdenv; })
      # :lang latex & :lang org (latex previews)
      texlive.combined.scheme-medium
      (openssh.override { stdenv = myClangStdenv; })
      (mosh.override { stdenv = myClangStdenv; })
      (git.override { stdenv = myClangStdenv; })
      git-lfs
      (wget.override { stdenv = myClangStdenv; })
      rust-analyzer-nightly
    ];
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  programs.steam = {
    enable = true;
    remotePlay.openFirewall =
      true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall =
      true; # Open ports in the firewall for Source Dedicated Server
  };
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.asusd.enable = true;
  services.asusd.enableUserService = true;
  services.supergfxd.enable = true;
  systemd.services.supergfxd.path = [ pkgs.pciutils ];

  #  hardware.opengl = {
  #    enable = true;
  #    driSupport = true;
  #    driSupport32Bit = true;
  #  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" "amdgpu" "radeonsi" ];

  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    powerManagement.enable = false;
    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of 
    # supported GPUs is at: 
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus 
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;
    dynamicBoost.enable = true;
    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  #    hardware.nvidia.prime = {
  #      offload = {
  #  			enable = true;
  #  			enableOffloadCmd = true;
  #  		};
  #      # Make sure to use the correct Bus ID values for your system!
  #      nvidiaBusId = "PCI:1:0:0";
  #      amdgpuBusId = "PCI:5:0:0";
  #    };
  networking.extraHosts = ''
    192.168.122.173 ghc-plus-linux                    
  '';
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
  boot.kernelParams = [ "mitigations=off" ];
  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

}
