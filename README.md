# JustinMohnsIPod — NixOS config

Flake-based system config. Host `JustinMohnsIPod`, `x86_64-linux`,
nixpkgs `master` (unstable channel, pinned via flake.lock).

## Layout

| File | Purpose |
|---|---|
| `flake.nix` | Inputs + outputs. One `nixosConfigurations.JustinMohnsIPod`. |
| `configuration.nix` | The entire system module (big, ~30KB). |
| `hardware-configuration.nix` | Generated hardware bits. |
| `xz.nix` | Local xz overrides. |
| `cachix.nix` + `cachix/` | Binary caches. |
| `.gitmodules` | Legacy submodules (firefox-overlay, hnix, inochi-nixpkgs) — mostly historical, the flake uses direct inputs now. |

## Notable flake inputs

- `nixpkgs` — master (unstable)
- `hermes-agent` — github:NousResearch/hermes-agent
- `cua` — github:trycua/cua (cua-driver, computer-use on Wayland)
- `fenix`, `emacs-overlay`, `simplex-chat`, `nix-gaming`, `nur`,
  `cosmic-screenshot`, `comfyui`, `gluon_language-server`, `hnix`

Rebuild: `sudo nixos-rebuild switch --flake .` (run from `/etc/nixos`)

## Hermes Agent setup (important — read before touching)

Installed as **packages only** (no `services.hermes-agent` NixOS module —
deliberate choice; the flake ships one but we don't use it).

```nix
hermes-agent.packages.${system}.desktop   # hermes-desktop (Electron chat UI)
hermes-agent.packages.${system}.default   # wrapped `hermes` CLI — REQUIRED
```

Package attribute notes:
- `default` == the "full" package (`full` is only an internal let-binding in
  the flake; the output attr is `default`). Installing `full` directly fails
  with "attribute does not exist".
- `tui` is just the Ink TUI frontend bundle, already shipped inside `default`
  via `HERMES_TUI_DIR`. Never install it standalone.
- The wrapped `hermes` binary self-sets `HERMES_BUNDLED_PLUGINS`,
  `HERMES_BUNDLED_SKILLS`, `HERMES_BUNDLED_LOCALES` via makeWrapper — these
  env vars are what make the gateway find its bundled platform adapters
  (Telegram/Discord/etc.), which are plugins, not hardcoded.

### Why both packages are needed

`desktop` gives only the Electron app, which spawns its own private
`hermes serve` backend for the chat UI. It never touches the gateway daemon.
Platform adapters (Telegram etc.) live ONLY in the gateway process, which is
the user systemd service `hermes-gateway.service`.

### The gateway service drop-in (do not remove)

`hermes gateway install` is Nix-unaware: it writes a base unit with
`ExecStart=<raw-venv-python> -m hermes_cli.main gateway run`, bypassing the
Nix wrapper → zero bundled plugins → `No adapter available for telegram`.

The fix lives at
`~/.config/systemd/user/hermes-gateway.service.d/override.conf`:

```ini
[Service]
ExecStart=
ExecStart=/etc/profiles/per-user/wrath/bin/hermes gateway run
```

This is update-proof by design:
- The profile path is stable; NixOS repoints the symlink on every rebuild.
- The wrapper self-sets all `HERMES_BUNDLED_*` vars — no hardcoded store
  hashes anywhere.
- It survives the gateway's boot-time unit self-heal
  (`refresh_systemd_unit_if_needed` rewrites only the base unit file,
  never drop-ins).
- The blank `ExecStart=` line is mandatory (systemd appends by default).

After changing it: `systemctl --user daemon-reload && systemctl --user
restart hermes-gateway`, then verify with
`journalctl --user -u hermes-gateway --since "1 min ago" | grep -i telegram`.
Journal lines prefixed `hermes[<pid>]` (vs `python[<pid>]`) prove the wrapper
is in charge.

DO NOT run `hermes gateway install` again blindly — it rewrites the base
unit (the drop-in still wins, but it regenerates a raw-venv ExecStart).

## Updating

```bash
cd /etc/nixos
nix flake update                    # update flake.lock
sudo nixos-rebuild switch --flake . # build + activate
git add flake.lock configuration.nix && git commit
```

## Git history conventions

Commits are terse one-liners describing the change
(e.g. `hermes: add default (full) package for wrapped hermes binary on PATH`).
