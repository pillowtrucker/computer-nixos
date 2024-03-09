{
  description = "Justin Mohn's IPod System Flake";

  inputs = {
    # NixOS official package source, here using the nixos-23.11 branch
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    nix-gaming.url = "github:fufexan/nix-gaming/master";
    nixpkgs-inochi.url = "github:TomaSajt/nixpkgs/inochi-session";
    nixpkgs-mozilla.url = "github:mozilla/nixpkgs-mozilla/master";
    fenix.url = "github:nix-community/fenix/main";
    emacs-overlay.url = "github:nix-community/emacs-overlay/master";
    simplex-chat.url = "github:simplex-chat/simplex-chat/stable";
    gluon_language-server.url = "github:pillowtrucker/gluon_language-server/nix";
    hnix.url = "github:haskell-nix/hnix/master";
    chigyutendiescum.url = "github:pillowtrucker/tooo000oooot";
#    flake-compat = {
#      url = "github:inclyc/flake-compat";
#      flake = false;
#    };
  };

  # The `self` parameter is special, it refers to
  # the attribute set returned by the `outputs` function itself.
  outputs = { self, nixpkgs, ... }@inputs: {
    # The host with the hostname `my-nixos` will use this configuration
    nixosConfigurations.JustinMohnsIPod = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs;};      
      modules = [
        ./configuration.nix
      ];
    };
  };
}
