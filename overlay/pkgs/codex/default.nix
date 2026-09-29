# Repackages llm-agents' codex into the complete package layout that
# `codex app-server daemon` requires (codex-package.json, codex-path/rg,
# codex-resources/bwrap). Without it, codex >= 0.157 fails at startup with
# "this CLI has no complete local package".
#
# Mirrors https://github.com/numtide/llm-agents.nix/pull/9889, but as a
# post-build rearrangement so the cached Rust build is reused. Drop this once
# that PR (or an equivalent) lands upstream.
{
  bubblewrap,
  codex,
  lib,
  ripgrep,
  runCommand,
  stdenv,
}: let
  packageManifest = builtins.toJSON {
    layoutVersion = 1;
    inherit (codex) version;
    target = stdenv.hostPlatform.rust.rustcTarget;
    variant = "codex";
    entrypoint = "bin/codex";
    resourcesDir = "codex-resources";
    pathDir = "codex-path";
  };
in
  runCommand "codex-${codex.version}" {
    inherit (codex) version meta passthru;
  } ''
    # On Linux upstream already moves the real binaries into libexec/ and
    # leaves a makeWrapper script in bin/; on Darwin bin/ holds them directly.
    src=${codex}/libexec/codex/bin
    [ -d "$src" ] || src=${codex}/bin

    root=$out/libexec/codex
    mkdir -p $root/{bin,codex-path,codex-resources} $out/bin

    # Copied, not symlinked: the daemon stages this tree and rejects links that
    # escape the package root.
    for exe in codex codex-code-mode-host logs_client; do
      install -Dm755 "$src/$exe" "$root/bin/$exe"
      ln -s ../libexec/codex/bin/$exe $out/bin/$exe
    done
    install -Dm755 ${lib.getExe ripgrep} $root/codex-path/rg
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      install -Dm755 ${lib.getExe bubblewrap} $root/codex-resources/bwrap
    ''}
    printf '%s\n' ${lib.escapeShellArg packageManifest} > $root/codex-package.json

    cp -r ${codex}/share $out/share
  ''
