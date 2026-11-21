# SPDX-License-Identifier: MIT OR Apache-2.0
{
  lib,
  craneLib,
  pkg-config,
  stdenv,
  systemd,
}: let
  commonArgs = {
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./src ./LICENSES ./NOTICE ./README.md];
    };
    nativeBuildInputs = [pkg-config];
    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [systemd];
  };
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
  craneLib.buildPackage (commonArgs
    // {
      inherit cargoArtifacts;
      passthru = {inherit cargoArtifacts;};
      # The HomeKit controller and ESPHome peer in the tests use loopback.
      __darwinAllowLocalNetworking = true;
      postInstall = ''
        install -Dm444 -t "$out/share/licenses/homekey-reader" LICENSES/Apache-2.0.txt LICENSES/MIT.txt NOTICE
      '';
      meta = {
        mainProgram = "homekey-reader";
        platforms = lib.platforms.unix;
        # The per-file choices and upstream exceptions are recorded in the crate.
        license = [lib.licenses.mit lib.licenses.asl20];
      };
    })
