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

## Hermes user plugins with Python deps (hermes-ircx-plugin)

The gateway's Python is a **sealed uv2nix venv** in /nix/store — read-only,
no pip. Any user plugin that needs extra Python packages (e.g. the
[hermes-ircx-plugin](https://github.com/computator1200/hermes-ircx-plugin)
IRC adapter, which needs `irctokens` + `ircstates`) needs the deps wired in
from the flake side.

What's set up here (2026-08-05):

1. **Plugin install:** `hermes plugins install
   "https://github.com/computator1200/hermes-ircx-plugin.git#plugins/platforms/ircx"`
   — the `#subdir` fragment picks the plugin out of the nested repo layout.
   Landed in `~/.hermes/plugins/ircx-platform`, enabled via
   `plugins.enabled` + `platforms.ircx.enabled: true`. Connection config
   (server/channel/nick/…) lives in `~/.hermes/.env` as `IRCX_*` vars —
   on the machine only, never committed. Channel logs go to
   `/opt/data/logs/ircx`.

2. **Deps via user profile (NOT the flake's extraPythonPackages hook).**
   The hermes flake offers `extraPythonPackages` overrides for exactly this,
   but it **cannot be used here**: its build-time collision checker hard-fails
   when an extra package ships something already in the sealed venv, and
   `ircstates` transitively pulls `python-dateutil` + `six` — both already in
   the venv. So instead:

   ```nix
   # configuration.nix — user packages, sourced from the hermes flake's OWN
   # nixpkgs pin so they track hermes's interpreter (nix/hermes-agent.nix
   # pins python312) and never drift from what hermes runs on:
   (let hermes-py = hermes-agent.inputs.nixpkgs.legacyPackages.${system}.python312Packages;
    in hermes-py.irctokens)   # (+ ircstates, pendulum, tzdata)
   ```

   These land in the user profile at the stable path
   `/etc/profiles/per-user/wrath/lib/python3.12/site-packages/`.
   `python-dateutil`/`six` are deliberately omitted — they resolve from the
   sealed venv at runtime.

3. **PYTHONPATH in the gateway drop-in** exposes the profile site-packages
   to the gateway process:

   ```ini
   Environment="PYTHONPATH=/etc/profiles/per-user/wrath/lib/python3.12/site-packages"
   ```

   (in `~/.config/systemd/user/hermes-gateway.service.d/override.conf`)

Maintenance: if a hermes flake update changes the venv interpreter's
major.minor (check `nix/hermes-agent.nix` in the hermes repo — currently
`python312`), update the `pythonXXXPackages` attribute above and the
PYTHONPATH path in the drop-in together, then rebuild + restart the gateway.

Verify after a gateway restart: `grep -i ircx ~/.hermes/logs/gateway.log`
should show `IRCX: connected to <server>:<port> as <nick>; joined
<channel>` and `✓ ircx connected`.

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

## Remote access (VNC/RDP/Wayland)

State of the art on Wayland: capture goes through xdg-desktop-portal
ScreenCast + PipeWire; input goes through uinput (or the portal's
RemoteDesktop session). Anything that speaks X11-only (wayvnc, krfb's
old X11 path) does not see a Wayland session.

What's set up here:

1. **KRDP — KDE's built-in RDP server** (ships with plasma6 module,
   no extra package). Shadows the *running* Wayland session over RDP.
   - Config: `~/.config/krdpserverrc` (PAM auth via
     `SystemUserEnabled=true` → your normal login; TLS cert at
     `~/.local/share/krdpserver/krdp.{crt,key}`, self-signed 10y).
   - User unit: `app-org.kde.krdpserver.service` (enabled).
   - Connect: any RDP client → `<host>:3389`, username `wrath`,
     login password. Self-signed cert warning is expected.
   - **LAN-only by design** (laptop is in the router DMZ):
     `networking.firewall.extraInputRules` accepts 3389 only from
     `192.168.1.0/24`. Do NOT move 3389 into `allowedTCPPorts`.
2. **rustdesk-flutter** installed for the user. RustDesk captures
   Wayland via portal/PipeWire and injects input via uinput. The
   *flutter* client is required — the sciter client (`rustdesk`)
   cannot capture Wayland sessions.
3. **cua-driver (computer-use) on Wayland** needs
   `CUA_DRIVER_RS_ENABLE_WAYLAND=1`. Set in two places:
   - `~/.config/environment.d/99-cua-wayland.conf` → systemd user
     manager (hermes-gateway service).
   - `~/.config/plasma-workspace/env/99-cua-wayland.sh` → everything
     started inside the Plasma session (incl. hermes-desktop).
   KWin support is experimental; per-window portal capture works,
   whole-screen geometry is flaky.

## SSH agent (gpg-agent SSH support + KWallet auto-unlock)

The SSH agent is **gpg-agent's SSH support** (`programs.gnupg.agent.enableSSHSupport`),
not a standalone ssh-agent. Historically the prezto `ssh` module started its own
agent and symlinked it onto gpg-agent's `S.gpg-agent.ssh`; that chain is retired.
All user processes get the socket directly via `~/.config/environment.d/99-ssh-auth.conf`
(`SSH_AUTH_SOCK=/run/user/1000/gnupg/S.gpg-agent.ssh`).

Why SSH never prompts for passphrases:
- `~/.gnupg/gpg-agent.conf`: `default-cache-ttl-ssh`/`max-cache-ttl-ssh` = 1 year
  (the 2h default `max-cache-ttl` was the recurring pinentry prompt) +
  `allow-preset-passphrase`.
- `security.pam.services.login.kwallet.enable = true` — SDDM substacks `login`,
  so pam_kwallet auto-unlocks the KWallet at login when the wallet password
  matches the login password.
- `~/.config/plasma-workspace/env/99-ssh-unlock.sh` presets every key in
  `~/.gnupg/sshcontrol` from KWallet at login (silent).
- One-time seeding: `~/.config/ssh/seed-kwallet.sh` — stores passphrases in
  KWallet (entries `ssh-passphrase-<keygrip>`) and presets the agent.

New keys: run `ssh-add <key>` once (pinentry prompt), then re-run the seed
script. The hermes-gateway unit gets `SSH_AUTH_SOCK` via its drop-in
(`~/.config/systemd/user/hermes-gateway.service.d/override.conf`).

## WireGuard VPN (VPS-hosted, laptop = client)

The VPN moved off the laptop onto the VPS on 2026-08-08 — the laptop's WAN
ingress was IPv6-only/filtered anyway, and the VPS has clean public v4+v6.
New topology: subnet 10.0.30.0/24 — VPS .1 (server), laptop .2, phone .3.
The laptop-hosted server (old 10.0.20.0/24, `wg0` here) was retired once
phone + laptop both migrated.

- **VPS server:** WireGuard on the VPS, listens UDP 51820, subnet
  10.0.30.0/24. Its endpoint hostname is an unguessable subdomain of
  a domain I control (grey-cloud A record to the VPS IP) — deliberately NOT
  written here; it lives in machine-local files only.
- **Laptop client:** `networking.wireguard.interfaces.wg1` (10.0.30.2/32),
  outbound-only, auto-connects. Private key `/etc/wireguard/wg-vps.key`
  (root-only, not in repo). The peer endpoint is applied at boot by
  `wg1-endpoint.service` reading `/etc/wireguard/wg1.endpoint` (root-only) —
  pure flake evaluation can't read files outside the repo, so no
  `builtins.readFile` trick; the unguessable hostname never lands here.
- **Firewall model:** the laptop exposes NOTHING to the WAN anymore.
  SSH 22, KRDP 3389, opencode web 4096-5016, hermes A2A 9900 — all
  `interfaces.wg1`-scoped: reachable only via the VPN subnet or the LAN.
  The old UDP-51820 WAN rule is gone.
- **Bot-to-bot:** both Hermes gateways talk over the tunnel via the A2A
  platform (laptop hermes <-> vps hermes, port 9900, bearer tokens in each
  side's .env). Verified both ways 2026-08-08.
- **Phone config:** `~/wireguard-phone-vps.conf` + QR, same keypair as
  before (just new server pubkey/address/endpoint), split tunnel
  (10.0.30.0/24 only), keepalive 25s. Old laptop-based configs
  (`wireguard-phone.conf`, `-v6.conf`) are retired.
- **DDNS retired:** `~/.local/bin/cloudflare-ddns.sh` + timer are disabled —
  the VPS IPs are static, no dynamic hostname needed. (The old A/AAAA
  records for the laptop hostname stay as harmless leftovers or can be
  deleted.)
- Verify: `sudo wg show wg1` (handshake + endpoint 51820),
  `systemctl status wg1-endpoint`, ping 10.0.30.1.
