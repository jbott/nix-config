{
  lib,
  darwin,
  fetchFromGitHub,
  stdenv,
}: let
  name = "m1ddc";
  version = "1.2.0-unstable-20241229";
in
  stdenv.mkDerivation {
    inherit name version;

    src = fetchFromGitHub {
      owner = "waydabber";
      repo = "m1ddc";
      rev = "2549fec9f0bfe01a51f2ba1ee558d20933273e10";
      hash = "sha256-obs2qQvSkIDsWhCXJOF1Geiqqy19KDf0InyxRVod4hk=";
    };

    patches = [
      ./01-ioregistry-apple_sdk_11_0.patch
    ];

    installPhase = ''
      install -Dt $out/bin m1ddc
    '';

    meta = with lib; {
      platforms = platforms.darwin;
    };
  }
