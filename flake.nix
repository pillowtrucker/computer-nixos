{
  description = "Justin Mohn's IPod System Flake";

  inputs = {
    # NixOS official package source, here using the nixos-23.11 branch
    #  nixpkgs.url = "github:pillowtrucker/nixpkgs/fix-ca-dervs-rez";
    nixpkgs.url = "github:nixos/nixpkgs/master";
    nix-gaming.url = "github:fufexan/nix-gaming/master";
    #    nixpkgs-inochi.url = "github:TomaSajt/nixpkgs/inochi-session"; # merged
    #    nixpkgs-mozilla.url = "github:mozilla/nixpkgs-mozilla/master";
    #    nixpkgs-ruby-ca.url =
    #      "github:tie/nixpkgs/f391429b917a2f9ffb4136808c73fe3e11e46acd"; # finally merged
    fenix.url = "github:nix-community/fenix/main";
    emacs-overlay.url = "github:nix-community/emacs-overlay/master";
    simplex-chat.url = "github:simplex-chat/simplex-chat/stable";
    gluon_language-server.url = "github:pillowtrucker/gluon_language-server/nix";
    hnix.url = "github:haskell-nix/hnix/master";
    nur.url = "github:nix-community/NUR";
    #    crow-translate.url = "git+https://invent.kde.org/pillowtrucker/crow-flake";
    cosmic-screenshot.url = "github:pillowtrucker/cosmic-flake";
    #    nixpkgs-llvm18-update.url =
    #      "github:ExpidusOS/nixpkgs/1c5df86c3d30e6a8d43113f1400641cdd7709da9";
    comfyui.url = "github:utensils/comfyui-nix";
    # LOCAL PATCHED checkout (2026-08-09): telegram exactly-once inbound fix.
    # git+file (not path:) so ignored churn (__pycache__ etc.) can't drift the
    # input hash; only committed content is hashed. (Hit 2026-08-19: path input
    # NAR-mismatched after pycache regenerated in the clone.)
    # Rollback: revert to "github:NousResearch/hermes-agent", re-lock, rebuild.
    # Full story: patches/hermes-telegram-exactly-once.patch.
    hermes-agent.url = "git+file:///etc/nixos/hermes-agent";
    cua.url = "github:trycua/cua";
    claude-desktop.url = "github:heytcass/claude-desktop-linux-flake";
    # Tangled CLI (`tang`) — decentralized git collaboration platform client
    # on AT Protocol. Used for pushing to tangled.org remotes.
    # Sourced from the local checkout (~/impro_flake/tangled-cli, the same fork
    # tag + branch this machine's user profile installs) instead of a remote
    # knot/handle URL, so the operator's DID handle never lands in flake.lock.
    # Rollback: point back at the upstream repo, re-lock, rebuild.
    #   tangled-cli.url = "git+https://tangled.org/jubishop.bsky.social/tangled-cli";
    tangled-cli.url = "git+file:///home/wrath/impro_flake/tangled-cli";
    # tcl-lsp - own Tcl/Tk language server (Rust, links libtcl and uses
    # Tcl's own parser). git+file local input: only committed content is
    # hashed, so commit before rebuilding after edits to the project.
    tcl-lsp.url = "git+file:///home/wrath/tcl-lsp-flake";
    # veles-agent — own Rust+Tcl agent runtime. Provides the veles CLI
    # and `services.veles` (nixosModules.default), which also builds and
    # wires the sandbox artifacts (nspawn rootfs, firecracker guest
    # kernel + rootfs) for whichever fence is configured.
    #
    # git+file (not path:) for the same reason as hermes-agent above:
    # only COMMITTED content is hashed, so ignored churn cannot drift the
    # input. Commit in ~/veles-agent before rebuilding, or the rebuild
    # keeps using the previous commit.
    #
    # `?ref=master` since 2026-09-04: every working branch was merged
    # into master, and a ref left pointing at a merged branch silently
    # keeps rebuilding an older commit.
    #
    # See /etc/nixos/README.md § Veles Agent.
    veles-agent.url = "git+file:///home/wrath/veles-agent?ref=master";
  };

  # The `self` parameter is special, it refers to
  # the attribute set returned by the `outputs` function itself.
  outputs =
    {
      self,
      nixpkgs,
      nur,
      ...
    }@inputs:
    {
      nixosConfigurations.JustinMohnsIPod = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          nur.modules.nixos.default
          ./configuration.nix
        ];
      };
    };
}
