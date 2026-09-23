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
| `qwen-code.nix`, `crow-translate.nix`, `bailian-cli.nix` + `bailian-cli-package-lock.json` | Locally packaged upstream software via the overlay (qwen-code: GitHub tag, pnpm workspace — upstream retired package-lock.json in 0.24.2; crow: local checkout; bailian-cli `bl`: pinned npm tarball — not in nixpkgs). |
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

## Python for agents

`users.users.wrath.packages` carries ONE python env:
`(python3.withPackages (ps: with ps; [ requests httpx rich pyyaml pillow numpy pandas
... ]))`. Not a bare `python3` plus separate `python-*` entries: the env
provides `bin/python` and `bin/python3` itself, and modules installed as
separate profile entries would not land on that interpreter's sys.path.

No pip in the env on purpose - the store is read-only, so `pip install` can
only ever fail. `uv` (also in the profile) is the venv tool for per-project
dependencies. Add a module by appending it to the withPackages list and
rebuilding.

## Git history conventions

Commits are terse one-liners describing the change
(e.g. `hermes: add default (full) package for wrapped hermes binary on PATH`).

This repo is public and must only ever carry one identity. `.githooks/`
enforces that: `pre-commit` scans staged content and filenames, `commit-msg`
scans the message, and both check the author/committer git will actually
stamp. Enabled per-clone with:

    git config core.hooksPath .githooks

The banned-pattern list is deliberately **not** tracked here — committing it
would republish the very strings it exists to keep out. It lives machine-local
at `/etc/nixos-identity-guard/patterns.txt` (override with
`$IDENTITY_GUARD_PATTERNS`), same reasoning as `/etc/wireguard/wg1.endpoint`.
The guard fails closed: no readable pattern file means no commit.

Audit all existing history (blobs, messages, and author/committer fields) with
`.githooks/identity-guard.sh --all`.

Watch out for `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` / `GIT_COMMITTER_*` in the
environment: they override `~/.gitconfig` silently, so `git config user.email`
can report the right identity while every commit is recorded under a different
one. The hooks check the effective identity precisely because config alone is
not enough.

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

## Ollama CORS origins

The ollama service needs `OLLAMA_ORIGINS` set so browser-based clients
(web apps + browser extensions) can reach the local API. The allowed
domains live in a **machine-local env file** (same pattern as the
WireGuard endpoint/key files — never committed to this public repo):

- File: `/etc/ollama/origins.env` (root:root 0640)
- Format: systemd `EnvironmentFile` (`KEY=value`, one per line)
- Key: `OLLAMA_ORIGINS` — comma-separated origin patterns (glob-style,
  ollama uses Go `path.Match`)

The committed `configuration.nix` references only the file path via
`systemd.services.ollama.serviceConfig.EnvironmentFile`; the actual
origin list is in the machine-local file only.

Systemd `EnvironmentFile=` values override `Environment=` for the same
key, so all origins (including non-secret ones like extension schemes)
go in the file.

To add a new origin: edit `/etc/ollama/origins.env` and restart the
service: `sudo systemctl restart ollama`.

## kdotool, dotool, ydotool

System-wide packages for KDE Wayland window control and input injection.
`kdotool` (not in nixpkgs) is built from `github:jinliu/kdotool` via a
`buildRustPackage` let-binding in `configuration.nix`; `dotool` and
`ydotool` are from nixpkgs. Full usage docs and cua-driver workaround
recipe: `kdotool` Hermes skill.

## tcl-lsp (own Tcl/Tk language server)

Installed from the local project checkout via a `git+file:///home/wrath/tcl-lsp-flake`
flake input (`inputs.tcl-lsp.packages.${system}.tcl-lsp` in `users.users.wrath.packages`).
The Nix wrapper bakes Tcl/Tk runtime paths plus nagelfar and tclint/tclfmt as
defaults, so the binary is self-contained. The Emacs client is loaded from the
project working tree (`~/.emacs.d/init.el`, `:load-path
~/tcl-lsp-flake/editors/emacs/`); it prefers a `tcl-lsp` found on `exec-path`
(direnv/envrc wins) over the system binary. Commit in the project before
rebuilding the system, since the flake input only sees committed content.
Project usage docs live in the project repo itself.

## Veles Agent

Own Rust + Tcl agent runtime (`~/veles-agent`). Added 2026-09-04, at
**user level**: the `veles` CLI is in `users.users.wrath.packages`, the
gateway is a systemd **user** unit running as wrath against wrath's own
directories, and anything needing root goes through `sudo`. Nothing runs
as a system service and nothing touches `/var/lib`.

### What was added

| where | what | why |
| --- | --- | --- |
| `flake.nix` | `veles-agent.url = "git+file:///home/wrath/veles-agent?ref=tasks-shells-monitors"` | the `hermes-agent` precedent — `git+file`, not `path:`, so only committed content is hashed |
| `configuration.nix` imports | `inputs.veles-agent.nixosModules.default` | the `services.veles` module |
| `users.users.wrath.packages` | `veles-agent.packages.${system}.default` | the wrapped `veles` on wrath's PATH |
| `users.users.wrath.extraGroups` | `"kvm"` | the firecracker sandbox opens `/dev/kvm` |
| `users.users.wrath.autoSubUidGidRange` | `true` | rootless podman needs subuid/subgid ranges, or `podman run` dies in `newuidmap` |
| `virtualisation.podman` / `virtualisation.containers` | enabled | this box had **neither podman nor docker**, so `scripts/build-sandbox-image.sh` could not run here at all |
| `environment.systemPackages` | `firecracker`, `e2fsprogs` | the microVM fence, and the `mkfs.ext4` it runs per sandboxed run |
| `services.veles` | enabled, `scope = "user"`, `gateway.enable = true`, `gateway.devTree = "veles-agent"`, `sandbox.backend = "firecracker"` | see below |

### Two gateway units

A gateway is long-lived: it holds the IRC/Telegram adapters, the desktop
API, and the cron scheduler (the only thing that fires cron jobs). The
module installs **two** user units and no toggle:

| unit | runs | wanted at login |
| --- | --- | :-: |
| `veles-gateway` | the veles nix built — pinned | yes |
| `veles-gateway-dev` | `~/veles-agent/target/debug/veles` | no |

```sh
systemctl --user status veles-gateway        # the nix-built one
systemctl --user start  veles-gateway-dev    # the working tree, this session

# at every login — symlink it from the system store:
ln -s /etc/systemd/user/veles-gateway-dev.service \
      ~/.config/systemd/user/default.target.wants/
systemctl --user disable veles-gateway-dev   # undoes that symlink
```

Not `systemctl --user enable`: like most NixOS units these are `static`
(no `[Install]` section — NixOS generates one only from `wantedBy`,
which would also plant a root-owned symlink under `/etc` that you could
not remove). `enable` warns there is no installation config and just
copies the unit into your directory, where it shadows rather than
enables. `disable` does undo a hand-made symlink.

**Current state on this machine (2026-09-04):** `veles-gateway-dev` is
symlinked into `~/.config/systemd/user/default.target.wants/` and
running; `veles-gateway` is installed and stopped.

Run **one at a time**: both hold the same pid file and the same ports.
The dev unit runs a binary nix did not build and does not own — every
`cargo build` in `~/veles-agent` replaces the running daemon's
executable. That is what it is for; a machine you depend on should be on
`veles-gateway`.

`gateway.devTree` is relative to `$HOME` and reaches the unit as
systemd's `%h`, so no username appears in the unit file.

Until 2026-09-04 this said `gateway.enable = false` and told you to run
`systemctl --user start veles`. There was no such unit — `enable = false`
means the module generates none — and what was actually running was a
hand-written `~/.config/systemd/user/veles-gateway.service` from
2026-08-22 pointing at `target/debug/veles`. That file has been deleted:
a unit in the user's own directory SHADOWS the module's, so leaving it
would have made this whole section inert.

### The sandbox artifacts are wired, not just configured

`sandbox.backend = "firecracker"` makes the module **build** the guest
kernel and rootfs and point `[sandbox] kernel_path` / `image` at those
store paths. A config that names an artifact nobody built is precisely
the failure this coupling prevents — the backend shipped 2026-09-03 with
a config contract and no artifacts at all.

The **guest kernel is not this machine's kernel**; firecracker loads its
own `vmlinux` and the running kernel is untouched. It is built from the
same source though — `config.boot.kernelPackages.kernel`, i.e. xanmod —
with one config delta that is the whole reason a custom kernel is
needed:

```
CONFIG_VIRTIO_MMIO=m  CONFIG_VIRTIO_BLK=m  CONFIG_EXT4_FS=m     # stock
CONFIG_VIRTIO_MMIO=y  CONFIG_VIRTIO_BLK=y  CONFIG_EXT4_FS=y     # guest
```

A firecracker guest boots with no initrd, so it has nowhere to load a
module from and cannot find its own root device. Expect one kernel build
the first time; it caches after that.

### Proving it

```sh
veles doctor              # config, provider route chain, store, Tcl
veles doctor --sandbox    # resolves the fence AND runs a script through it
```

`doctor --sandbox` is not a readout: it resolves `[sandbox]`, reports the
binary and each artifact, then executes `puts [expr {6*7}]` through the
fence and checks for `42`. Non-zero exit on failure.

Per backend, on this machine:

```sh
cd ~/veles-agent
scripts/sandbox_vm_check.sh local      # native, nspawn (sudo), firecracker, podman
scripts/sandbox_vm_check.sh freebsd    # the jail fence, in ~/crow-ci/ci-freebsd.qcow2
scripts/build-sandbox-image.sh         # the ubuntu dev-sandbox image, for podman
```

**nspawn needs a writable rootfs.** `systemd-nspawn` takes a lock *next
to* the rootfs, so a `/nix/store` path fails with `Failed to lock …:
Read-only file system`. Stage a copy once (the check script does it for
you):

```sh
cp -a "$(nix build ~/veles-agent#nspawnRootfs --no-link --print-out-paths)" \
   ~/.local/share/veles/sandbox/nspawn-root
chmod -R u+w ~/.local/share/veles/sandbox/nspawn-root
```

nspawn is root-gated by the backend itself, so it runs under `sudo` —
which is the posture for this box, not an oversight.

### Where veles keeps its files

Since 2026-09-04 veles follows XDG, and the old single `~/.veles` was
migrated automatically on first run:

```
~/.config/veles        config.toml, .env, secrets.env, themes, commands, plugins, skills
~/.local/share/veles   state.db, checkpoints, memory.d, media, certs, backups, logs
~/.cache/veles         regenerable working files
~/.veles/MOVED-TO-XDG  a breadcrumb naming every destination
```

`veles migrate-dirs --dry-run` shows the plan without touching anything.
`VELES_HOME` still forces the old single-directory layout — the OCI
image (`VELES_HOME=/opt/data`) depends on it.

### Updating

`git+file` hashes **committed** content only:

```sh
cd ~/veles-agent && git commit -am "…"          # first
sudo nix flake lock /etc/nixos --update-input veles-agent
sudo nixos-rebuild switch --flake /etc/nixos#JustinMohnsIPod
```

Skipping the commit leaves the rebuild on the previous revision, silently.

### Rolling back

Remove the `services.veles` block, the `veles-agent` package line, the
import and the flake input, then rebuild — or
`sudo nixos-rebuild switch --rollback`. podman, the `kvm` group and the
subuid ranges are independently useful and can stay.

## libvirt loses its firewall rules on a `nixos-rebuild switch`

Added 2026-09-04 alongside the veles work, because it is what broke the
FreeBSD CI VM and it will break any guest on `virbr0`.

libvirt's nftables backend installs `table ip libvirt_network` — the
forward rules and the masquerade that gives guests on the `default`
network a route out — **once per daemon lifetime**, and caches the fact
that it did. NixOS's `firewall.service` flushes the ruleset when it
(re)starts, which a `nixos-rebuild switch` does. The table goes; libvirtd
believes it is still there and never puts it back. Nothing is logged.

The symptom is not "no network". The virtual network stays `active`,
guests keep their DHCP addresses, and they can still reach the host —
including dnsmasq, so **DNS answers**. Only the outside world is gone:
every outbound TCP connection hangs. `pkg`/`apt` inside the guest sit in
`connect()` forever.

What it looks like when you try to fix it by hand:

```
$ virsh -c qemu:///system net-start default
error: internal error: Failed to apply firewall command
  'nft -ae insert rule ip libvirt_network guest_output iif virbr0 counter reject':
  Error: Could not process rule: No such file or directory
```

— the *table* the rule targets is missing, not the rule.

Diagnose with `sudo nft list tables`: if `ip libvirt_network` is absent
while a NAT network is running, this is it. `sudo systemctl restart
libvirtd` fixes it immediately.

The durable fix, in `configuration.nix`:

```nix
systemd.services.libvirtd = {
  after = [ "firewall.service" ];
  partOf = [ "firewall.service" ];
};
```

`partOf` propagates the firewall's restarts to libvirtd, which rebuilds
its table. Restarting libvirtd does **not** disturb running guests —
their qemu processes are not children of the daemon.

### The CI VMs on this machine

`ci-freebsd` (192.168.122.60) and `ci-linux` (192.168.122.50) are
libvirt domains on the `default` network, cloud-init provisioned with a
`ci` account and `~/.ssh/ci-vm`, reachable as `ssh ci-freebsd` /
`ssh ci-linux` through `~/.ssh/config`. veles' `scripts/sandbox_vm_check.sh`
uses those domains; its old code booted the qcow2 by hand with qemu user
networking, which puts the guest on 10.0.2.x with no seed drive and
makes the provisioned accounts look absent.

One more trap worth writing down: a guest whose `/etc/resolv.conf`
points at an unreachable nameserver **accepts the TCP connection on port
22 and never sends an SSH banner**, because FreeBSD's sshd does a
reverse lookup through libwrap first. `ssh` reports "Connection timed out
during banner exchange", which reads like a broken sshd. `ci-freebsd`
had `nameserver 10.0.2.3` — QEMU user-mode's DNS — left behind by an
ad-hoc boot.
