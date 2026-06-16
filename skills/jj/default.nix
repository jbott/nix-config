{
  lib,
  runCommandLocal,
}: let
  # Only the user-facing skill files belong in the installed plugin — the
  # tests/ subtree is benchmark scaffolding and this default.nix is the
  # nix build recipe itself; neither should land in the runtime output.
  skillSrc = lib.cleanSourceWith {
    src = ./.;
    filter = path: type: let
      relative = lib.removePrefix (toString ./. + "/") path;
    in
      relative
      != "default.nix"
      && !(lib.hasPrefix "tests" relative);
  };
in
  runCommandLocal "jj-skill" {
    meta = {
      description = "jj (Jujutsu) skill for Claude Code (tests live alongside in skills/jj/tests/)";
      homepage = "https://github.com/johnaott/nix-config";
      license = lib.licenses.mit;
    };
  } ''
    mkdir -p $out
    cp -r ${skillSrc}/. $out/
  ''
