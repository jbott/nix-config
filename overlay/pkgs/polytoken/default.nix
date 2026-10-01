{
  lib,
  fetchurl,
  stdenvNoCC,
  unzip,
  versionCheckHook,
}: let
  version = "0.8.17";
  targets = {
    "aarch64-darwin" = {
      platform = "macos-arm64";
      hash = "sha256-8y0rc8rVXsEYkr8sZkQ2fi0adoIkv1+3xqLJKDlmbEI=";
    };
    "aarch64-linux" = {
      platform = "linux-arm64";
      hash = "sha256-Jq3pW33W5wPK0NcxT1jHzYoI9kht31z6xMg8vDLqj9A=";
    };
    "x86_64-darwin" = {
      platform = "macos-amd64";
      hash = "sha256-l2Xw7J5YyGpCcPYzpUat+jBQAZzS1s3iKXFOxOyNPP0=";
    };
    "x86_64-linux" = {
      platform = "linux-amd64";
      hash = "sha256-vfFBVxCnGlcuvt8HUQhFfJ80xtVB/bnh2sRrJr8GYUQ=";
    };
  };
  target = targets.${stdenvNoCC.hostPlatform.system};
in
  stdenvNoCC.mkDerivation {
    pname = "polytoken";
    inherit version;

    src = fetchurl {
      url = "https://dl.polytoken.dev/${version}/${target.platform}/polytoken.zip";
      inherit (target) hash;
    };

    nativeBuildInputs = [unzip];

    unpackPhase = ''
      runHook preUnpack
      mkdir source
      unzip -q "$src" -d source
      runHook postUnpack
    '';
    sourceRoot = "source";

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      install -Dm755 polytoken $out/bin/polytoken
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];
    versionCheckProgramArg = "--version";

    meta = {
      description = "Coding harness for AI-assisted software development";
      homepage = "https://polytoken.dev";
      license = lib.licenses.unfree;
      mainProgram = "polytoken";
      platforms = builtins.attrNames targets;
    };
  }
