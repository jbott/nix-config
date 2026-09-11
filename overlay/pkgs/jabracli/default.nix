{
  lib,
  fetchurl,
  stdenvNoCC,
  cpio,
  gzip,
  versionCheckHook,
  xar,
}: let
  version = "1.6.48.0";
in
  stdenvNoCC.mkDerivation {
    pname = "jabracli";
    inherit version;

    src = fetchurl {
      url = "https://file.cloud.jabra.com/cli-tool/JabraCLI_${version}.pkg";
      hash = "sha256-0H37RMCMrFx3amBpct7AYz+NBtQ3+AgHrehuwFQDcGI=";
    };

    nativeBuildInputs = [cpio gzip xar];

    # The installer's other component, "Jabra Firmware Update.app", needs a
    # system extension that only the system installer can register, so only the
    # CLI is unpacked here.
    unpackPhase = ''
      runHook preUnpack

      xar -xf $src
      gunzip -dc JabraCLIOnly.pkg/Payload | cpio -idm --quiet

      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      install -d "$out/bin" "$out/libexec/jabracli"
      cp -R usr/local/jabracli/. "$out/libexec/jabracli/"
      ln -s ../libexec/jabracli/jabracli "$out/bin/jabracli"

      runHook postInstall
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];
    versionCheckProgramArg = "--version";

    meta = {
      description = "Command line tool for managing Jabra personal and meeting room devices";
      homepage = "https://developer.jabra.com/sdks-and-tools/jabracli/";
      license = lib.licenses.unfree;
      mainProgram = "jabracli";
      # The macOS installer is built for arm64 only.
      platforms = ["aarch64-darwin"];
    };
  }
