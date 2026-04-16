{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  writeShellApplication,
  versionCheckHook,
  bubblewrap,
  socat,
  curl,
  jq,
  coreutils,
  nix,
}: let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin-x64";
    aarch64-darwin = "darwin-arm64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform} or (throw "Unsupported system: ${platform}");

  updateScript = writeShellApplication {
    name = "update-claude-code";
    runtimeInputs = [curl jq coreutils nix];
    text = builtins.readFile ./update.sh;
  };
in
  stdenv.mkDerivation {
    pname = "claude-code";
    inherit version;

    src = fetchurl {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/${platformSuffix}/claude";
      hash = hashes.${platform};
    };

    dontUnpack = true;
    dontStrip = true; # bun runtime; stripping breaks it

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/claude
      runHook postInstall
    '';

    # --argv0 preserves "claude" as the process name (rather than
    # ".claude-wrapped").
    postFixup = ''
      wrapProgram $out/bin/claude \
        --argv0 claude \
        --set DISABLE_AUTOUPDATER 1 \
        --set DISABLE_INSTALLATION_CHECKS 1 \
        ${lib.optionalString stdenv.hostPlatform.isLinux "--prefix PATH : ${lib.makeBinPath [bubblewrap socat]}"}
    '';

    # Bun links against /usr/lib/libicucore.A.dylib which needs ICU data from
    # /usr/share/icu/ at runtime for Intl.Segmenter. Nix's macOS sandbox
    # blocks that path, causing "failed to initialize Segmenter".
    __noChroot = stdenv.hostPlatform.isDarwin;

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    passthru.updateScript = updateScript;

    meta = {
      description = "Agentic coding tool from Anthropic (vendored binary release)";
      homepage = "https://claude.ai/code";
      changelog = "https://github.com/anthropics/claude-code/releases";
      license = lib.licenses.unfree;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      mainProgram = "claude";
      platforms = lib.attrNames platformMap;
    };
  }
