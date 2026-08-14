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
    # Rollback: revert to "github:NousResearch/hermes-agent", re-lock, rebuild.
    # Full story: patches/hermes-telegram-exactly-once.patch.
    hermes-agent.url = "path:/etc/nixos/hermes-agent";
    cua.url = "github:trycua/cua";
    claude-desktop.url = "github:heytcass/claude-desktop-linux-flake";
    # Tangled CLI (`tang`) — decentralized git collaboration platform client
    # on AT Protocol. Used for pushing to tangled.org remotes.
    # PINNED (2026-08-14) to a fork+branch fixing two real bugs that block
    # addressing any pull/issue record authored by someone other than the
    # caller (`tang pull show/review/merge <at-uri-or-did:rkey>` and
    # `--target owner/repo` for a fork's upstream both failed). PR open
    # upstream: https://tangled.org/DID-OPERATOR-REDACTED/tangled-cli/pulls
    # (rkey 3mt23o5wzy42u). Points at the knot directly by repoDid rather
    # than the fork's own handle/reponame path - the latter 404s for a
    # just-created repo (frontend indexing lag), while the knot itself
    # already serves it fine. Rollback: revert to
    # "git+https://tangled.org/jubishop.bsky.social/tangled-cli", re-lock,
    # rebuild. Once the PR merges upstream, switch back to that same line.
    tangled-cli.url = "git+https://knot.tangled.example.invalid/DID-OPERATOR-REDACTED?ref=fix-parse-record-id-cross-account-ids";

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
