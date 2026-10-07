{
  lib,
  fetchurl,
  stdenvNoCC,
  unzip,
  versionCheckHook,
}: let
  version = "0.8.19";
  targets = {
    "aarch64-darwin" = {
      platform = "macos-arm64";
      hash = "sha256-iieGhdzx6oTP0MGORw4IKq7yQ5XRzDnewGO85gZeptc=";
    };
    "aarch64-linux" = {
      platform = "linux-arm64";
      hash = "sha256-+uzrEBEp/FGwFjuZ1vRqcgguFI3l+Gf149NXz5zZoL0=";
    };
    "x86_64-darwin" = {
      platform = "macos-amd64";
      hash = "sha256-WZhGf/EhX19F5ZEH1XZzDIJXSeNDyu6pm/C3PMJeoQ4=";
    };
    "x86_64-linux" = {
      platform = "linux-amd64";
      hash = "sha256-Zaa9zCn//YEOae8K4i73pPDFoplrXJkOzWnBZ7zPZpU=";
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
