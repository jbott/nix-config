{
  lib,
  darwin,
  fetchFromGitHub,
  stdenv,
}: let
  name = "blueutil";
  version = "2.9.1";
in
  stdenv.mkDerivation {
    inherit name version;

    src = fetchFromGitHub {
      owner = "toy";
      repo = "blueutil";
      rev = "v${version}";
      hash = "sha256-dxsgMwgBImMxMMD+atgGakX3J9YMO2g3Yjl5zOJ8PW0=";
    };

    buildInputs = with darwin.apple_sdk.frameworks; [IOBluetooth];

    # The makefile incorrectly (for GNUMake, at least) specifies CFLAGS rather
    # than OBJCFLAGS, so inline a copy here
    OBJCFLAGS = "-mmacosx-version-min=10.9 -framework Foundation -framework IOBluetooth";

    installPhase = ''
      install -Dt $out/bin blueutil
    '';

    meta = with lib; {
      platforms = platforms.darwin;
    };
  }
