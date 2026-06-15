{
  lib,
  stdenvNoCC,
}:
# yolo reads its codename word lists at runtime, so the script ships with
# @modifiers@/@nouns@ placeholders that get rewritten to absolute store paths
# at install time. Keeping the script and its data files in one derivation is
# why this lives here rather than in the catchall scripts buildEnv.
stdenvNoCC.mkDerivation {
  pname = "yolo";
  version = "0.1.0";

  src = ./.;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 yolo-modifiers.txt $out/share/yolo/yolo-modifiers.txt
    install -Dm644 yolo-nouns.txt $out/share/yolo/yolo-nouns.txt

    install -Dm755 yolo $out/bin/yolo
    substituteInPlace $out/bin/yolo \
      --replace-fail @modifiers@ $out/share/yolo/yolo-modifiers.txt \
      --replace-fail @nouns@ $out/share/yolo/yolo-nouns.txt

    runHook postInstall
  '';

  meta = {
    description = "Launch Claude Code with --dangerously-skip-permissions, named sessions, and jj worktrees";
    mainProgram = "yolo";
    platforms = lib.platforms.unix;
  };
}
