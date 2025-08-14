{
  lib,
  stdenv,
  python3,
}:
stdenv.mkDerivation rec {
  pname = "gen-firefox-profile-launchers";
  version = "1.0.0";

  src = ./.;

  buildInputs = [python3];

  installPhase = ''
    mkdir -p $out/bin
    cp gen-firefox-profile-launchers.py $out/bin/gen-firefox-profile-launchers
    chmod +x $out/bin/gen-firefox-profile-launchers
  '';

  meta = with lib; {
    description = "Create macOS app launcher stubs for Firefox profiles";
    longDescription = ''
      Parses Firefox profiles.ini and creates macOS application launcher stubs
      in ~/Applications/ for all non-default Firefox profiles.
    '';
    homepage = "https://github.com/nixos/nixpkgs";
    license = licenses.mit;
    platforms = platforms.darwin;
    maintainers = [];
  };
}
