{
  description = "Justin Mohn's IPod System Flake";

  inputs = {
    # NixOS official package source, here using the nixos-23.11 branch
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    nix-gaming.url = "github:fufexan/nix-gaming/master";
    nixpkgs-inochi.url = "github:TomaSajt/nixpkgs/inochi-session";
    nixpkgs-mozilla.url = "github:mozilla/nixpkgs-mozilla/master";
    nixpkgs-ruby-ca.url = "github:tie/nixpkgs/f391429b917a2f9ffb4136808c73fe3e11e46acd";
    fenix.url = "github:nix-community/fenix/main";
    emacs-overlay.url = "github:nix-community/emacs-overlay/master";
    simplex-chat.url = "github:simplex-chat/simplex-chat/stable";
    gluon_language-server.url = "github:pillowtrucker/gluon_language-server/nix";
    hnix.url = "github:haskell-nix/hnix/master";
#    chigyutendiescum.url = "github:pillowtrucker/tooo000oooot";
    nur.url = "github:nix-community/NUR";
#    flake-compat = {
#      url = "github:inclyc/flake-compat";
#      flake = false;
#    };
#    nixseparatedebuginfod.url = "github:symphorien/nixseparatedebuginfod"; # already in nixpkgs
  };

  # The `self` parameter is special, it refers to
  # the attribute set returned by the `outputs` function itself.
  outputs = { self, nixpkgs, nur, ... }@inputs: {
    # The host with the hostname `my-nixos` will use this configuration
    nixosConfigurations.JustinMohnsIPod = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs;};      
      modules = [
#        nixseparatedebuginfod.nixosModules.default # already in nixpkgs
        nur.nixosModules.nur
        ./configuration.nix
      ];
    };
  };
}
