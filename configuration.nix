# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, programs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./cachix.nix
    ];

#  nixpkgs.localSystem.platform = pkgs.lib.systems.platforms.pc64 // {
#    gcc.arch = "zenv3";
#    gcc.tune = "zenv3";
# };
#  nixpkgs.config.replaceStdenv = pkgs.clangStdenv;
  nixpkgs.hostPlatform = {
    gcc.arch = "znver3";
    gcc.tune = "znver3";
    system = "x86_64-linux";
  };
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/efi";
  nix.settings.trusted-users = [ "root" "wrath" ];

  networking.hostName = "JustinMohnsIPod"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
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
#    enableFontDir = true;
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-table-other
      fcitx5-chinese-addons
      fcitx5-configtool
      libsForQt5.fcitx5-qt
      fcitx5-table-extra
    ];
  };  

  # Configure keymap in X11
  services.xserver.xkb.layout = "gb";
  services.xserver.xkb.options = "compose:ralt";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;
    
  nixpkgs.overlays = [ #(import /etc/nixos/firefox-overlay.nix)
                       (import "${fetchTarball "https://github.com/mozilla/nixpkgs-mozilla/archive/master.tar.gz"}/firefox-overlay.nix")
                       (import "${fetchTarball "https://github.com/nix-community/fenix/archive/main.tar.gz"}/overlay.nix")
                       (import (builtins.fetchGit {
                         url = "https://github.com/nix-community/emacs-overlay.git";
                         ref = "master";
#                         rev = "bfc8f6edcb7bcf3cf24e4a7199b3f6fed96aaecf"; # change the revision
    }))
#                       (final: prev: let pkgs' = import <nixpkgs> {}; in { stdenv = pkgs'.impureUseNativeOptimizations pkgs'.clangStdenv;
#                                     })
#                       (final: prev: let pkgs' = import <nixpkgs> {}; in { stdenv = pkgs'.clangStdenv;
#                                     })
#                       (final: prev: {
#                         config = prev.config.override (attrs: { replaceStdenv = ({ pkgs }: pkgs.impureUseNativeOptimizations pkgs.Clangstdenv);});
#                                     })
#                     (_: super: let pkgs = fenix.inputs.nixpkgs.legacyPackages.${super.system}; in fenix.overlays.default pkgs pkgs)
  ];



  nixpkgs.config.allowUnfree = true;
#  nixpkgs.config.replaceStdenv = pkgs.impureUseNativeOptimizations pkgs.Clangstdenv;
#  nixpkgs.config.replaceStdenv = llvmPackages_17.stdenv;
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  users.users.root.initialHashedPassword = "";
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.wrath = {
    uid = 1000;
    initialHashedPassword = "";
    isNormalUser = true;
    home = "/home/wrath";
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    
    packages = with pkgs; [
      (calibre.override {stdenv = llvmPackages_17.stdenv;})
      (pavucontrol.override {stdenv = llvmPackages_17.stdenv;})
      (obs-studio.override {stdenv = llvmPackages_17.stdenv;})
      (telegram-desktop.override {stdenv = llvmPackages_17.stdenv;})
      blender
      ldtk
      (strawberry.override {stdenv = llvmPackages_17.stdenv;})
#      rustup
#      (yakuake.override {stdenv = llvmPackages_17.stdenv;})
      yakuake
      (tree.override {stdenv = llvmPackages_17.stdenv;})
      (qbittorrent.override {stdenv = llvmPackages_17.stdenv;})
      (furnace.override {stdenv = llvmPackages_17.stdenv;})
      (nmap.override {stdenv = llvmPackages_17.stdenv;})
#      chromium
      (cmake.override {stdenv = llvmPackages_17.stdenv;})
      (element-desktop.override {stdenv = llvmPackages_17.stdenv;})
      (fontforge.override {stdenv = llvmPackages_17.stdenv;})
      (gimp.override {stdenv = llvmPackages_17.stdenv;})
      (lshw.override {stdenv = llvmPackages_17.stdenv;})
      (libreoffice-qt.override {stdenv = llvmPackages_17.stdenv;})
      #libreoffice-qt
#      (lutris.override {stdenv = llvmPackages_17.stdenv;})
      lutris
#      (lyx.override {stdenv = llvmPackages_17.stdenv;})
      lyx
#      (mpv.override {stdenv = llvmPackages_17.stdenv;})
      mpv
#      vscode # I probably don't need this since I got gluon lsp working with emacs
    ];
  };
  services.emacs.enable = true;
#  services.emacs.package = import /home/wrath/.emacs.d { pkgs = pkgs; };
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  programs.firefox.enable = true;
  programs.firefox.package = pkgs.latest.firefox-nightly-bin;

security.sudo = {
  enable = true;
  wheelNeedsPassword = false;
};
environment.systemPackages = with pkgs; [
  (lynx.override {stdenv = pkgs.llvmPackages_17.stdenv;})
  (tmux.override {stdenv = pkgs.llvmPackages_17.stdenv;})
  (htop.override {stdenv = pkgs.llvmPackages_17.stdenv;})
  (nvtop.override {stdenv = pkgs.llvmPackages_17.stdenv;})
  (iftop.override {stdenv = pkgs.llvmPackages_17.stdenv;})
    (pkgs.emacsWithPackagesFromUsePackage {
      package = pkgs.emacs.override {stdenv = pkgs.llvmPackages_17.stdenv;};  # replace with pkgs.emacsPgtk, or another version if desired.
      config = /home/wrath/.emacs.d/init.el;})
    (ripgrep.override {withPCRE2 = true; stdenv = pkgs.llvmPackages_17.stdenv;})
  (gnutls.override {stdenv = pkgs.llvmPackages_17.stdenv;})              # for TLS connectivity
#  (fd.override {stdenv = pkgs.llvmPackages_17.stdenv;})                  # faster projectile indexing
  fd
  (imagemagick.override {stdenv = pkgs.llvmPackages_17.stdenv;})         # for image-dired
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
#     (fenix.complete.withComponents [
#      "cargo"
#      "clippy"
#      "rust-src"
#      "rustc"
#      "rustfmt"
#    ])
#    rust-analyzer-nightly
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

  
  # Enable OpenGL
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

