# qwen-code built from the upstream release tag via its pnpm workspace.
#
# 0.24.2 retired package-lock.json in favour of pnpm-lock.yaml (#11859), so
# the previous buildNpmPackage recipe (fetchNpmDeps over a package-lock)
# can no longer express this package. This file uses the pnpm machinery
# nixpkgs ships (fetchPnpmDeps + pnpmConfigHook, fetcherVersion 4).
#
# Version bumps:
#   1. Change `version` below.
#   2. Refresh the src hash:
#        nix store prefetch-file --unpack --json \
#          "https://codeload.github.com/QwenLM/qwen-code/tar.gz/refs/tags/v<ver>"
#   3. Set pnpmDeps.hash to lib.fakeHash, build once, copy the `got:` hash
#      back (fetchPnpmDeps hashes the pnpm store materialised from the
#      lockfile; it is sensitive to the exact pnpm version used).
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_11,
  nodejs_22,
  git,
  ripgrep,
  pkg-config,
  glib,
  libsecret,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "qwen-code";
  version = "0.24.4";

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    tag = "v${finalAttrs.version}";
    hash = "sha256-8Twmne99CJ9OE0z7t/fmPPa+FDvPDK34+8ma7ePV0aA=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-m6sOBjtFGWpwzjANu5+YEcLe6bhnSMzgkn6FpYp+y7o=";
  };

  nativeBuildInputs = [
    pnpmConfigHook
    pnpm_11
    nodejs_22
    pkg-config
    git
  ];

  buildInputs = [
    ripgrep
    glib
    libsecret
  ];

  # The build script shells out to `corepack pnpm`, which would try to
  # fetch pnpm@11.24.0 from the network mid-build; point it at the pnpm
  # already on PATH instead. (Its "install if node_modules missing" gate
  # never fires here: pnpmConfigHook materialised node_modules.)
  postPatch = ''
    substituteInPlace scripts/build.js \
      --replace-fail "corepack pnpm" "pnpm"
  '';

  buildPhase = ''
    runHook preBuild

    # pnpmConfigHook installs with --ignore-scripts, so root's patch-package
    # postinstall has not run yet. It applies patches/ink+7.0.3.patch, which
    # the CLI imports at runtime (getFrameController) and the build needs.
    pnpm exec patch-package

    # Upstream's own --cli-only build order covers everything the CLI
    # bundle pulls in (core, channels, acp-bridge, sdk, web-templates...)
    # without tracking the workspace list by hand across releases.
    node scripts/build.js --cli-only
    npm run bundle

    runHook postBuild
  '';

  # Mirror the nixpkgs expression: ship dist/ + pruned production
  # node_modules (runtime externals: @lydell/node-pty prebuilds), and
  # upstream's cli-entry.js wrapper (relaunches cli.js with --expose-gc).
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/qwen-code
    cp -r dist/* $out/share/qwen-code/
    cp scripts/cli-entry.js $out/share/qwen-code/cli-entry.js
    cp package.json $out/share/qwen-code/package.json

    # pnpm-native prune: `npm prune` here tries to re-resolve against
    # the registry (EAI_AGAIN in the sandbox) and cannot read pnpm's layout.
    # CI=true: without it pnpm aborts the modules purge for lack of a TTY
    # (ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY).
    CI=true pnpm prune --prod --ignore-scripts
    cp -r node_modules $out/share/qwen-code/
    # Remove symlinks that point into the build tree.
    find $out/share/qwen-code/node_modules -type l -delete || true
    patchShebangs $out/share/qwen-code

    ln -s $out/share/qwen-code/cli-entry.js $out/bin/qwen

    runHook postInstall
  '';

  meta = {
    description = "Coding agent that lives in digital world";
    homepage = "https://github.com/QwenLM/qwen-code";
    mainProgram = "qwen";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [ ];
  };
})