{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  makeWrapper,
  versionCheckHook,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "claude-code-modes";
  version = "0.2.13";

  src = fetchFromGitHub {
    owner = "nklisch";
    repo = "claude-code-modes";
    rev = "v${finalAttrs.version}";
    hash = "sha256-v5hSpGxsQLu7lIdYfPJFLAZgar/QLCC9oMPLanL9NJY=";
  };

  nativeBuildInputs = [bun makeWrapper];

  dontConfigure = true;
  dontStrip = true; # bun runtime; stripping breaks it

  buildPhase = ''
    runHook preBuild

    # bun writes to $HOME for its install cache; the source has no runtime
    # deps (only devDeps for @types/bun) so we just need a writable HOME.
    export HOME=$TMPDIR

    bun run scripts/generate-prompts.ts
    bun run scripts/generate-build-info.ts
    bun build src/cli.ts --compile --outfile=claude-mode

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 claude-mode $out/bin/claude-mode
    runHook postInstall
  '';

  # Disable claude-mode's self-update check: this is a Nix-managed binary,
  # and the network fetch at startup is pointless when the version is pinned.
  postFixup = ''
    wrapProgram $out/bin/claude-mode \
      --set CLAUDE_MODE_NO_UPDATE_CHECK 1
  '';

  # Bun on macOS links against /usr/lib/libicucore.A.dylib which needs ICU
  # data from /usr/share/icu/ at runtime; Nix's macOS sandbox blocks that
  # path, breaking both `bun build` and the install-check invocation.
  __noChroot = stdenv.hostPlatform.isDarwin;

  doInstallCheck = true;
  nativeInstallCheckInputs = [versionCheckHook];
  versionCheckProgramArg = "--version";

  meta = {
    description = "CLI launcher for Claude Code with behaviorally-tuned system prompts";
    homepage = "https://github.com/nklisch/claude-code-modes";
    changelog = "https://github.com/nklisch/claude-code-modes/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "claude-mode";
    platforms = lib.platforms.unix;
  };
})
