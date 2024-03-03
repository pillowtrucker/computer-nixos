# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, programs, ... }:
let
  nix-gaming = import (builtins.fetchTarball "https://github.com/fufexan/nix-gaming/archive/master.tar.gz");
  in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./cachix.nix
    ];
  boot.tmp.useTmpfs = false; # webkit explodes this, firefox nearly does
#  nixpkgs.localSystem.platform = pkgs.lib.systems.platforms.pc64 // {
#    gcc.arch = "zenv3";
#    gcc.tune = "zenv3";
# }; # this is deprecated
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
  
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/efi";
  nix.settings.keep-derivations = true;
  nix.settings.keep-outputs = true;
#  nix.settings.auto-optimise-store = true;
  nix.settings.trusted-users = [ "root" "wrath" ];
  nix.settings.cores = 8;
  nix.settings.max-jobs = 2;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.allow-import-from-derivation = true;
  networking.hostName = "JustinMohnsIPod"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

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
      (nerdfonts.override { fonts = [ "Iosevka" "FiraCode" "Inconsolata" "JetBrainsMono" "Hasklig" "Meslo" ]; })
    ];
    fontconfig = {
      defaultFonts = {
        monospace = [ "Hasklig" ];
        sansSerif = [ "FiraGO" "Source Sans Pro" ];
        serif = [ "ETBembo" "Source Serif Pro" ];
      };
    };
    fontDir.enable = true;
  };

  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;
  
  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-skk
      libsForQt5.fcitx5-qt
#      fcitx5-mozc # broken download link, don't care enough to fix
      fcitx5-table-other
      fcitx5-chinese-addons
      fcitx5-configtool
      fcitx5-table-extra
    ];
  };  

  services.xserver.xkb.layout = "gb";
  services.xserver.xkb.options = "compose:ralt";

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
  services.xserver.libinput.enable = true;
    
  nixpkgs.overlays = [ 
                       (import "${fetchTarball "https://github.com/mozilla/nixpkgs-mozilla/archive/master.tar.gz"}/firefox-overlay.nix")
                       (import "${fetchTarball "https://github.com/nix-community/fenix/archive/main.tar.gz"}/overlay.nix")
                       (import (builtins.fetchGit {
                         url = "https://github.com/nix-community/emacs-overlay.git";
                         ref = "master";
#                         rev = "bfc8f6edcb7bcf3cf24e4a7199b3f6fed96aaecf"; # change the revision
                       }))
                       (self: super: {
                         ccacheWrapper = super.ccacheWrapper.override {
                           extraConfig = ''
                             export CCACHE_COMPRESS=1
                             export CCACHE_DIR="${config.programs.ccache.cacheDir}"
                             export CCACHE_UMASK=007
                             if [ ! -d "$CCACHE_DIR" ];      then
                               echo "====="
                               echo "Directory '$CCACHE_DIR' does not exist"
                               echo "Please create it with:"
                               echo "sudo mkdir -m0770 '$CCACHE_DIR'"
                               echo "  sudo chown root:nixbld '$CCACHE_DIR'"
                               echo "=====" 
                               exit 1        
                             fi             
                             if [ ! -w "$CCACHE_DIR" ]; then
                               echo "====="        
                               echo "Directory '$CCACHE_DIR' is not accessible for user $(whoami)"
                               echo "Please verify its access permissions"
                               echo "====="       
                               exit 1            
                             fi     
                           '';      
                         };
                       })
                       (final: prev: let pkgs = import <nixpkgs> {}; in {
                                           opencolorio = prev.opencolorio.overrideAttrs (attrs: {
                                             cmakeFlags = attrs.cmakeFlags ++ ["-DOCIO_BUILD_TESTS=OFF"];
                                           });
                                           blender = prev.blender.override {
                                             stdenv = final.ccacheStdenv;
                                             colladaSupport = true;
                                           };
                                           mpv = prev.wrapMpv (prev.mpv.unwrapped.override {stdenv = final.llvmPackages_17.stdenv; rubberbandSupport = false;}) {};
                                           
                                           tzdata = prev.tzdata.overrideAttrs (attrs: {
                                             doCheck = false;
                                             checkTarget = "";
                                           });
                                           haskellPackages = prev.haskellPackages.override {
                                             overrides = haskellSelf: haskellSuper: {
                                               x509-validation = final.haskell.lib.dontCheck haskellSuper.x509-validation;
                                             };
                                           };
                                           live555 = prev.live555.overrideAttrs (attrs: rec {
                                             version = "2024.02.28";
                                             src = prev.fetchurl {
                                               url = "https://github.com/museoa/live555-backups/raw/tarballs/live.${version}.tar.gz";
                                               sha256 ="sha256-5WjtkdqoofZIijunfomcEeWj6l4CUK9HRoYAle2jSx8=";
                                             };
                                           });
                                           ccache = prev.ccache.overrideAttrs (attrs: rec {
                                             version = prev.ccache.version;
                                             src = prev.fetchFromGitHub {
                                               owner = "ccache";
                                               repo = "ccache";
                                               rev = "refs/tags/v${version}";
                                               sha256 = "sha256-Rhd2cEAEhBYIl5Ej/A5LXRb7aBMLgcwW6zxk4wYCPVM=";
                                             };});
                                           a52dec = prev.a52dec.overrideAttrs (attrs: rec {
                                             version = "0.7.4";
                                             src = prev.fetchurl {
                                               url = "https://ftp2.osuosl.org/pub/blfs/conglomeration/a52dec/a52dec-${version}.tar.gz";
                                               sha256 = "oh1ySrOzkzMwGUNTaH34LEdbXfuZdRPu9MJd5shl7DM=";
                                             };
                                           });
#                                           llvmPackages_17 = prev.llvmPackages_17.overrideAttrs (llvm17-final: llvm17-prev: {
#                                             llvm = llvm17-prev.llvm.override {stdenv = final.ccacheStdenv;};
#                                             clang = llvm17-prev.clang.override {stdenv = final.ccacheStdenv;};
#                                             compiler-rt = llvm17-prev.compiler-rt.override {stdenv = final.ccacheStdenv;};
#                                           });
#                                           llvmPackages_16 = prev.llvmPackages_16.overrideAttrs (llvm16-final: llvm16-prev: {
#                                             llvm = llvm16-prev.llvm.override {stdenv = final.ccacheStdenv;};
#                                             clang = llvm16-prev.clang.override {stdenv = final.ccacheStdenv;};
#                                             compiler-rt = llvm16-prev.compiler-rt.override {stdenv = final.ccacheStdenv;};
#                                           });
                                           libsForQt5 = prev.libsForQt5.overrideScope (qt5-final: qt5-prev: {
                                             qtwebkit = qt5-prev.qtwebkit.overrideAttrs {stdenv = final.ccacheStdenv;};
                                             qtwebengine = qt5-prev.qtwebengine.overrideAttrs {stdenv = final.ccacheStdenv;};
                                             qtwebsockets = qt5-prev.qtwebsockets.overrideAttrs {stdenv = final.ccacheStdenv;};
                                           });
                                           plasma5Packages = prev.plasma5Packages.overrideScope (plasma5-final: plasma5-prev: {
                                             qtwebkit = plasma5-prev.qtwebkit.overrideAttrs {stdenv = final.ccacheStdenv;};
                                             qtwebengine = plasma5-prev.qtwebengine.overrideAttrs {stdenv = final.ccacheStdenv;};
                                             qtwebsockets = plasma5-prev.qtwebsockets.overrideAttrs {stdenv = final.ccacheStdenv;};
                                           });
                                           pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
                                             (
                                               python-final: python-prev: {
                                                 constantly = python-prev.constantly.overridePythonAttrs (oldAttrs: {src = pkgs.fetchFromGitHub {
                                                   owner = "twisted";
                                                   repo = "constantly";
                                                   rev = "refs/tags/${python-prev.constantly.version}";
                                                   hash = "sha256-yXPHQP4B83PuRNvDBnRTx/MaPaQxCl1g5Xrle+N/d7I=";
                                                 };});
                                                 numpy = python-prev.numpy.overridePythonAttrs (oldAttrs: {
                                                   disabledTests = oldAttrs.disabledTests ++ ["test_umath_accuracy" "TestAccuracy::test_validate_transcendentals" "test_validate_transcendentals"];
                                                 });
                                               }
                                             )
                                           ];
                                           
                                         })
                       
  ];
#  programs.ccache.packageNames = ["xgcc" "webkit" "webkitgtk" "qtwebsockets" "qtwebengine" "qtwebkit" "libsForQt5.qtwebkit" "qt6Packages.qtwebkit" "libsForQt5.qtwebsockets" "qt6Packages.qtwebengine" "qt6Packages.qtwebsockets" "libsForQt6.qtwebengine" "chromium" "google-chrome" "llvmPackages_17.clang" "llvmPackages_17.llvm" "llvmPackages_17.compiler-rt" "llvmPackages_16.clang" "llvmPackages_16.llvm" "llvmPackages_16.compiler-rt"]; # TODO: figure out which of those even make sense and/or actually work
  programs.ccache.packageNames = ["chromium" "webkitgtk"];
#  programs.ccache.enable = true;  
#  programs.ccache.cacheDir = "/ccache";
#  nix.settings.extra-sandbox-paths = [ config.programs.ccache.cacheDir ];
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
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      yt-dlp
      nethack
#      adom # broken
      angband
      frotz
      netris
      sfrotz
      tintin
      scummvm
#      simplex-chat # not yet
      supercollider
      calibre
      (pavucontrol.override {stdenv = llvmPackages_17.stdenv;})
      obs-studio
      #      (telegram-desktop.override {stdenv = llvmPackages_17.stdenv;})
      (telegram-desktop.override {stdenv = ccacheStdenv;})
      (blender.overrideAttrs (attrs: {colladaSupport = true;
                                      cmakeFlags = attrs.cmakeFlags ++ ["-DWITH_CYCLES_EMBREE=OFF"];
                                      buildInputs = pkgs.lib.remove pkgs.embree attrs.buildInputs;
                                     }))
      ldtk
      (strawberry.override {stdenv = llvmPackages_17.stdenv;})
      yakuake
      (tree.override {stdenv = llvmPackages_17.stdenv;})
      (qbittorrent.override {stdenv = llvmPackages_17.stdenv;})
      (furnace.override {stdenv = llvmPackages_17.stdenv;})
      (nmap.override {stdenv = llvmPackages_17.stdenv;})
#      chromium # nah
      (cmake.override {stdenv = llvmPackages_17.stdenv;})
      (element-desktop.override {stdenv = ccacheStdenv;})
#      (element-desktop.override {stdenv = llvmPackages_17.stdenv;})
      fontforge
      (gimp.override {stdenv = llvmPackages_17.stdenv;})
      (lshw.override {stdenv = llvmPackages_17.stdenv;})
#      libreoffice-bin # fuck this, I barely even use this thing
#      (libreoffice-qt.override {stdenv = llvmPackages_17.stdenv;}) # probably need to disable llvm
      nix-gaming.packages.${pkgs.hostPlatform.system}.wine-ge
      mpv
      lutris
      lyx
#      vscode # I probably don't need this since I got gluon lsp working with emacs
    ];
  };
  services.emacs.enable = true;
  programs.firefox.enable = true;
  programs.firefox.package = (pkgs.wrapFirefox.override { stdenv = pkgs.ccacheStdenv; }) pkgs.firefox-devedition-unwrapped { };
#  programs.firefox.package = (pkgs.wrapFirefox.override { stdenv = pkgs.llvmPackages_17.stdenv; }) pkgs.firefox-devedition-unwrapped { };
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

environment.systemPackages = with pkgs; [
  wgetpaste
  binwalk
  w3m
  clang-tools
  bat
  nix-tree
  nix-du
  nix-diff
  smartmontools
  lm_sensors
  neomutt
#  cpupower
  nixd
  nil
  (lynx.override {stdenv = pkgs.llvmPackages_17.stdenv;})
  (tmux.override {stdenv = pkgs.llvmPackages_17.stdenv;})
  (htop.override {stdenv = pkgs.llvmPackages_17.stdenv;})
  nvtop # reenable maybe if the stupid ssl test stops failing # first trying with channel update, maybe they unjanked it
  (iftop.override {stdenv = pkgs.llvmPackages_17.stdenv;})
  (pkgs.emacsWithPackagesFromUsePackage {
    package = pkgs.emacs.override {stdenv = pkgs.llvmPackages_17.stdenv;};  # replace with pkgs.emacsPgtk, or another version if desired.
    config = /home/wrath/.emacs.d/init.el;})
  (ripgrep.override {withPCRE2 = true; stdenv = pkgs.llvmPackages_17.stdenv;})
  (gnutls.override {stdenv = pkgs.llvmPackages_17.stdenv;})              # for TLS connectivity
#  (fd.override {stdenv = pkgs.llvmPackages_17.stdenv;})                  # faster projectile indexing
  fd
#  (imagemagick.override {stdenv = pkgs.llvmPackages_17.stdenv;})         # for image-dired
  (zstd.override {stdenv = pkgs.llvmPackages_17.stdenv;})                # for undo-fu-session/undo-tree compression
    # :tools lookup & :lang org +roam
  (sqlite.override {stdenv = pkgs.llvmPackages_17.stdenv;})
    # :lang latex & :lang org (latex previews)
    texlive.combined.scheme-medium
  (openssh.override {stdenv = pkgs.llvmPackages_17.stdenv;})
#    latest.firefox-nightly-bin
  (mosh.override {stdenv = pkgs.llvmPackages_17.stdenv;})
  (git.override {stdenv = pkgs.llvmPackages_17.stdenv;})
#  (git-lfs.override {stdenv = pkgs.llvmPackages_17.stdenv;})
  git-lfs
  (wget.override {stdenv = pkgs.llvmPackages_17.stdenv;})
#  (fenix.complete.withComponents [
#    "cargo"
#    "clippy"
#    "rust-src"
#    "rustc"
#    "rustfmt"
#  ])
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
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };
  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.asusd.enable = true;
  services.asusd.enableUserService = true;
  services.supergfxd.enable = true;
  systemd.services.supergfxd.path = [ pkgs.pciutils ];

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

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
		
    hardware.nvidia.prime = {
      offload = {
			  enable = true;
			  enableOffloadCmd = true;
		  };
    # Make sure to use the correct Bus ID values for your system!
    nvidiaBusId = "PCI:1:0:0";
    amdgpuBusId = "PCI:5:0:0";
  };
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
  boot.kernelPackages = pkgs.linuxPackages_lqx;
  boot.kernelParams = [
    "mitigations=off"
  ];
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
