{
  lib,
  fetchFromGitHub,
  buildGoModule,
  buildNpmPackage,
  apple-sdk_15,
}: let
  pname = "finicky";
  version = "4.3.0-alpha-unstable-2026-03-16";
  rev = "08eb1d3cb12ce59407abd90b51131015c48a86d9";

  src = fetchFromGitHub {
    owner = "johnste";
    repo = "finicky";
    inherit rev;
    hash = "sha256-HT7rGHRV9c0GDyE6VU46nowvXYbDdsEEdp+1eravBmo=";
  };

  configApi = buildNpmPackage {
    pname = "finicky-config-api";
    inherit version src;
    sourceRoot = "source/packages/config-api";
    npmDepsHash = "sha256-w5if926gtcq2LJW4uvvR9g5mAe1vgBzyxyeczHvmq6Y=";
    postBuild = ''
      npm run generate-types
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp dist/finickyConfigAPI.js $out/
      cp dist/finicky.d.ts $out/
      runHook postInstall
    '';
  };

  finickyUi = buildNpmPackage {
    pname = "finicky-ui";
    inherit version src;
    sourceRoot = "source/packages/finicky-ui";
    npmDepsHash = "sha256-TRbZ2YMvY8palWD7vImQhjbeVYKu4tsmctA/CIBGwhQ=";
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/. $out/
      runHook postInstall
    '';
  };
in
  buildGoModule {
    inherit pname version src;
    sourceRoot = "source/apps/finicky/src";
    vendorHash = "sha256-OMcQ2D8s5EmRrpHmTtjoLDbD97s+hB5bpCHyYTqKc2c=";

    buildInputs = [
      apple-sdk_15
    ];

    ldflags = [
      "-X finicky/version.commitHash=${builtins.substring 0 7 rev}"
      "-X finicky/version.buildDate=2026-03-16"
      "-X finicky/version.apiHost="
    ];

    preBuild = ''
      mkdir -p assets/templates
      cp ${configApi}/finickyConfigAPI.js assets/finickyConfigAPI.js
      cp -r ${finickyUi}/. assets/templates/
    '';

    installPhase = ''
      runHook preInstall

      local appDir="$out/Applications/Finicky.app/Contents"
      mkdir -p "$appDir/MacOS" "$appDir/Resources"

      cp "$GOPATH/bin/finicky" "$appDir/MacOS/Finicky"

      # Static bundle assets: Info.plist, Resources/{finicky,menu-bar}.icns
      cp -r "${src}/apps/finicky/assets/." "$appDir/"

      # Type definitions for user configs
      cp "${configApi}/finicky.d.ts" "$appDir/Resources/"

      runHook postInstall
    '';

    meta = with lib; {
      description = "A macOS application for customizing which browser is opened for every URL";
      homepage = "https://github.com/johnste/finicky";
      license = licenses.mit;
      platforms = ["aarch64-darwin" "x86_64-darwin"];
    };
  }
