{
  stdenv,
  lib,
  fetchurl,
  wrapQtAppsHook,
  dpkg,
  autoPatchelfHook,
  qtserialport,
  qtwebsockets,
  openssl,
  libredirect,
  makeWrapper,
  gzip,
  gnutar,
  nixosTests,
}:
stdenv.mkDerivation rec {
  pname = "deconz";
  version = "2.24.2";

  src = fetchurl {
    url = "https://deconz.dresden-elektronik.de/debian/beta/deconz_${version}-debian-buster-beta_arm64.deb";
    sha256 = "sha256-87TlxZJAVGM3P+lDoZ7JJrysXkvJm8Bv1U9/G31sKfI=";
  };

  # devsrc = fetchurl {
  #   url = "https://deconz.dresden-elektronik.de/raspbian/beta/deconz-dev-${version}.deb";
  #   sha256 = "";
  # };

  nativeBuildInputs = [dpkg autoPatchelfHook makeWrapper wrapQtAppsHook];

  buildInputs = [qtserialport qtwebsockets openssl];

  unpackPhase = ''
    runHook preUnpack

    dpkg -x $src ./deconz-src
    # dpkg -x $devsrc ./deconz-devsrc

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -r deconz-src/* "$out"
    # cp -r deconz-devsrc/* "$out"

    # Flatten /usr and manually merge lib/ and usr/lib/, since mv refuses to.
    mv "$out/lib" "$out/orig_lib"
    mv "$out/usr/"* "$out/"
    mkdir -p "$out/lib/systemd/system/"
    mv "$out/orig_lib/systemd/system/"* "$out/lib/systemd/system/"
    rmdir "$out/orig_lib/systemd/system"
    rmdir "$out/orig_lib/systemd"
    rmdir "$out/orig_lib"
    rmdir "$out/usr"

    for f in "$out/lib/systemd/system/"*.service \
             "$out/share/applications/"*.desktop; do
        substituteInPlace "$f" \
            --replace "/usr/" "$out/"
    done

    for p in "$out/bin/deCONZ" "$out/bin/GCFFlasher_internal.bin"; do
        wrapProgram "$p" \
            --set LD_PRELOAD "${libredirect}/lib/libredirect.so" \
            --set NIX_REDIRECTS "/usr/share=$out/share:/usr/bin=$out/bin" \
            --prefix PATH : "${lib.makeBinPath [gzip gnutar]}"
    done

    runHook postInstall
  '';

  passthru = {
    tests = {inherit (nixosTests) deconz;};
  };

  meta = with lib; {
    description = "Manage Zigbee network with ConBee, ConBee II or RaspBee hardware";
    homepage = "https://www.dresden-elektronik.com/wireless/software/deconz.html";
    license = licenses.unfree;
    platforms = with platforms; ["aarch64-linux"];
    sourceProvenance = with sourceTypes; [binaryNativeCode];
    maintainers = with maintainers; [bjornfor];
    mainProgram = "deCONZ";
  };
}
