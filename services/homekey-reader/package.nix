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
      fileset = lib.fileset.unions [./Cargo.toml ./Cargo.lock ./src ./LICENSE ./NOTICE];
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
      meta = {
        mainProgram = "homekey-reader";
        platforms = lib.platforms.unix;
        license = lib.licenses.asl20;
      };
    })
