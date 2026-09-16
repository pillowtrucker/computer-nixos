# bailian-cli (Aliyun Model Studio CLI: `bl` / `bailian`) — not in nixpkgs.
# Built from the pinned npm registry tarball (upstream publishes from a pnpm
# monorepo; the tarball ships the PREBUILT dist/ bundle + 4 runtime deps).
#
# Quirks this file handles:
#   - package.json devDependencies reference e2e@0.0.0, a workspace-only
#     package that does NOT exist on the npm registry. npm ci materialises
#     devDependencies, so they are stripped in postPatch. dist/ is
#     prebuilt; devDependencies are never needed at runtime.
#   - The tarball ships NO lockfile. One is generated from the PATCHED
#     manifest and vendored as ./bailian-cli-package-lock.json, copied in
#     in postPatch. fetchNpmDeps hashes the patched tree, so the vendored
#     lock must always match what postPatch produces.
#   - postinstall.js downloads ~2.3MB of wiki data from OSS at install
#     time. Stripped: `bl advisor recommend` / skill commands re-sync it
#     into ~/.bailian on first use (silent-failure design upstream, and
#     the sandbox has no network anyway).
#   - No build script runs (dontNpmBuild): `npm run build` is upstream's
#     `vp pack`, requiring the stripped devDependencies.
#
# Version bumps:
#   1. Change `version` below.
#   2. Refresh the src hash:
#        nix store prefetch-file --unpack --json \
#          "https://registry.npmjs.org/bailian-cli/-/bailian-cli-<ver>.tgz"
#   3. Regenerate the vendored lock against the patched manifest:
#        cd $(mktemp -d)
#        curl -sSLO \
#          https://registry.npmjs.org/bailian-cli/-/bailian-cli-<ver>.tgz
#        tar -xzf bailian-cli-<ver>.tgz package/package.json
#        jq 'del(.devDependencies, .scripts.postinstall)' \
#          package/package.json > package.json
#        npm install --package-lock-only --omit=dev --ignore-scripts \
#          --no-audit --no-fund
#        cp package-lock.json <repo>/bailian-cli-package-lock.json
#   4. Set npmDepsHash to lib.fakeHash, build once, copy the `got:` hash
#      back (same round-trip as qwen-code.nix).
{
  lib,
  buildNpmPackage,
  nodejs_22,
  fetchzip,
  jq,
}:

buildNpmPackage (finalAttrs: {
  pname = "bailian-cli";
  version = "1.25.0";

  # fetchzip (not fetchurl): the hash below is of the UNPACKED tree
  # (nix store prefetch-file --unpack). The npm tarball unpacks into a
  # top-level package/ directory.
  src = fetchzip {
    url = "https://registry.npmjs.org/bailian-cli/-/bailian-cli-${finalAttrs.version}.tgz";
    hash = "sha256-1a5Kj+fRCXjpftvBqx3qFzco9xSZSqYFO/11VPV0toI=";
  };

  # qwen-code precedent: npm 11 (shipped with newer nodejs) breaks
  # fetchNpmDeps (nixpkgs issue #474535).
  nodejs = nodejs_22;

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-5H0w9r7C0g8r+ll3LzkpcMamL5Mcl28h1XUID9G3hJQ=";

  nativeBuildInputs = [ jq ];

  postPatch = ''
    # e2e@0.0.0 (workspace-only) and the network-hitting postinstall must
    # not exist for npm ci in the sandbox; the vendored lockfile was
    # generated from exactly this patched manifest. NOTE: absolute jq path
    # (qwen-code pattern) because fetchNpmDeps re-applies postPatch in its
    # own derivation where nativeBuildInputs are NOT on PATH.
    ${jq}/bin/jq 'del(.devDependencies, .scripts.postinstall)' package.json > package.json.tmp
    mv package.json.tmp package.json
    cp ${./bailian-cli-package-lock.json} package-lock.json
    chmod +w package-lock.json
  '';

  # dist/ is prebuilt upstream.
  dontNpmBuild = true;

  preFixup = ''
    # Resolve `#!/usr/bin/env node` against the pinned nodejs.
    patchShebangs $out/lib/node_modules/bailian-cli/dist/bailian.mjs
  '';

  meta = {
    description = "CLI for Aliyun Model Studio (DashScope) AI Platform";
    homepage = "https://bailian.console.aliyun.com/cli";
    mainProgram = "bl";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [ ];
  };
})
