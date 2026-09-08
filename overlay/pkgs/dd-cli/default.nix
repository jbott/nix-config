{
  lib,
  fetchurl,
  stdenvNoCC,
  makeWrapper,
  versionCheckHook,
}: let
  version = "0.2.4";
  targets = {
    "aarch64-darwin" = {
      platform = "darwin-arm64";
      hash = "sha256-mWw1Getn5Ihy9Uby4U/U0gWPgeBRGCIZ+RxSYMpQcls=";
    };
    "x86_64-linux" = {
      platform = "linux-amd64";
      hash = "sha256-N+7AxyvLZjqvl1nqCY1J2cAiZruJXLv7rerkGGZgjdQ=";
    };
  };
  target = targets.${stdenvNoCC.hostPlatform.system};
in
  stdenvNoCC.mkDerivation {
    pname = "dd-cli";
    inherit version;

    src = fetchurl {
      url = "https://github.com/doordash-oss/doordash-cli/releases/download/v${version}/dd-cli-v${version}-${target.platform}.tar.gz";
      inherit (target) hash;
    };

    sourceRoot = "dd-cli-v${version}-${target.platform}";

    nativeBuildInputs = [makeWrapper];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      install -d "$out/bin" "$out/libexec/dd-cli"
      cp -R . "$out/libexec/dd-cli/"
      makeWrapper \
        "$out/libexec/dd-cli/dd-cli-v${version}-${target.platform}" \
        "$out/bin/dd-cli"

      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];
    versionCheckProgramArg = "--version";

    meta = {
      description = "DoorDash CLI for searching, ordering, and managing DoorDash orders";
      homepage = "https://github.com/doordash-oss/doordash-cli";
      license = lib.licenses.unfree;
      mainProgram = "dd-cli";
      platforms = builtins.attrNames targets;
    };
  }
