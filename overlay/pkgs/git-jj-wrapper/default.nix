{
  stdenv,
  lib,
  makeWrapper,
  jujutsu,
  git,
}:
stdenv.mkDerivation {
  pname = "git-jj-wrapper";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    substitute ${./git-jj-wrapper.sh} $out/bin/git \
      --replace-fail '@jj@' '${jujutsu}/bin/jj' \
      --replace-fail '@git@' '${git}/bin/git'
    chmod +x $out/bin/git

    runHook postInstall
  '';

  meta = with lib; {
    description = "Git wrapper that translates git commands to jj equivalents in jj workspaces";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
