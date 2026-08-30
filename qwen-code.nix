# qwen-code built from the upstream release tag, NOT the stale nixpkgs
# expression (stuck at 0.16.0). Installed via the overlay + bare-name lookup
# (same pattern as crow-translate.nix).
#
# Version bumps:
#   1. Change `version` below.
#   2. Refresh the src hash:  nix store prefetch-file --unpack \
#        "https://codeload.github.com/QwenLM/qwen-code/tar.gz/refs/tags/v<ver>"
#   3. Set npmDepsHash to lib.fakeHash, build once, copy the `got:` hash back.
#      The postPatch lockfile/package.json edits CHANGE the dependency set and
#      fetchNpmDeps applies the same postPatch, so the hash is against the
#      PATCHED lockfile (the fakeHash round-trip handles that).
#   4. Upstream patches/ are applied by patch-package during the
#      npm-config-hook's `npm rebuild` (postinstall). No manual patching
#      needed in this file.
#   5. Check root package.json optionalDependencies for new node-pty/keytar
#      platform packages: they must be stripped from BOTH the package.jsons
#      and the lockfile in lockstep or npm ci rejects the patched lock.
{
  lib,
  buildNpmPackage,
  nodejs_22,
  fetchFromGitHub,
  jq,
  git,
  ripgrep,
  pkg-config,
  glib,
  libsecret,
}:

buildNpmPackage (finalAttrs: {
  pname = "qwen-code";
  version = "0.22.3";

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4Epg8OVfPuU7w7vHA5U5Zi/mZNYVll/xW2ZBmvCD/p4=";
  };

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-VC4vMELuVCAu0OMSkMVfxILy1tKTG+DPYkzrn8FQgNU=";

  # npm 11 incompatible with fetchNpmDeps
  # https://github.com/NixOS/nixpkgs/issues/474535
  nodejs = nodejs_22;

  nativeBuildInputs = [
    jq
    pkg-config
    git
  ];

  buildInputs = [
    ripgrep
    glib
    libsecret
  ];

  # Unlike nixpkgs' expression we KEEP @lydell/node-pty and the linux
  # prebuilt binaries: 0.22.3's packages/core type-imports it (tsc fails
  # without it) and the esbuild bundle marks it external, loading the
  # prebuild at runtime (verified working under nodejs_22). Only keytar and
  # the darwin/win32 pty platform binaries are stripped. Their package.json
  # entries must be dropped in lockstep with the lockfile, or npm ci rejects
  # the patched lock as out of sync (0.22.3 declares the pty packages in
  # root + packages/core optionalDependencies; the old nixpkgs jq walk only
  # handles lockfile-internal dep objects, not the package.jsons).
  postPatch = ''
    strip_darwin_win() {
      ${jq}/bin/jq 'walk(
        if type == "object" and has("optionalDependencies") then
          .optionalDependencies |= with_entries(
            select(.key | test("node-pty-(darwin|win32)|keytar") | not))
        elif type == "object" and has("dependencies") then
          .dependencies |= with_entries(
            select(.key | test("node-pty-(darwin|win32)|keytar") | not))
        elif type == "object" and has("peerDependencies") then
          .peerDependencies |= with_entries(
            select(.key | test("node-pty-(darwin|win32)|keytar") | not))
        else .
        end
      )' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
    }
    for f in package.json packages/core/package.json; do
      strip_darwin_win "$f"
    done

    ${jq}/bin/jq '
      del(.packages."node_modules/keytar") |
      del(.packages."node_modules/@lydell/node-pty-darwin-arm64") |
      del(.packages."node_modules/@lydell/node-pty-darwin-x64") |
      del(.packages."node_modules/@lydell/node-pty-win32-arm64") |
      del(.packages."node_modules/@lydell/node-pty-win32-x64") |
      walk(
        if type == "object" then
          (if has("dependencies") then
            .dependencies |= with_entries(select(.key | test("node-pty-(darwin|win32)|keytar") | not))
          else . end) |
          (if has("optionalDependencies") then
            .optionalDependencies |= with_entries(select(.key | test("node-pty-(darwin|win32)|keytar") | not))
          else . end) |
          (if has("peerDependencies") then
            .peerDependencies |= with_entries(select(.key | test("node-pty-(darwin|win32)|keytar") | not))
          else . end)
        else .
        end
      )
    ' package-lock.json > package-lock.json.tmp && mv package-lock.json.tmp package-lock.json
  '';

  # Upstream's postinstall runs `patch-package`, which applies the MANDATORY
  # ink patch (patches/ink+7.0.3.patch adds getFrameController which the CLI
  # imports). npm ci itself runs --ignore-scripts, but the npm-config-hook
  # follows it with a bare `npm rebuild`, which DOES execute lifecycle
  # scripts (root postinstall incl.) - so patch-package has already applied
  # the ink patch by the time buildPhase runs. Do NOT patch manually here;
  # a second application makes `patch` prompt and fail the build.
  # Then build the workspace dist/ outputs the bundle step consumes, in
  # upstream's documented dependency order (scripts/build.js).
  buildPhase = ''
    runHook preBuild

    npm run build --workspace=@qwen-code/qwen-code-core
    npm run build --workspace=@qwen-code/web-templates
    npm run build --workspace=@qwen-code/channel-base
    for ch in telegram weixin dingtalk dws wecom feishu qqbot github gitlab; do
      npm run build --workspace=@qwen-code/channel-$ch
    done
    npm run build --workspace=@qwen-code/acp-bridge

    npm run generate
    npm run bundle

    runHook postBuild
  '';

  # Mirror the nixpkgs 0.16.0 expression: ship dist/ + pruned production
  # node_modules (runtime externals: @lydell/node-pty prebuilds and friends).
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/qwen-code
    cp -r dist/* $out/share/qwen-code/
    npm prune --omit=dev --no-save
    cp -r node_modules $out/share/qwen-code/
    # Remove symlinks that point into the build tree (workspace deps are
    # already bundled into dist/chunks; node_modules/.bin is not used).
    find $out/share/qwen-code/node_modules -type l -delete || true
    patchShebangs $out/share/qwen-code
    ln -s $out/share/qwen-code/cli.js $out/bin/qwen

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
