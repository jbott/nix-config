{
  lib,
  runCommandLocal,
  fetchFromGitHub,
}: let
  # Upstream: https://github.com/blader/humanizer — a portable "remove signs of
  # AI writing" skill. Pinned to a commit; bump rev + hash to update. Only the
  # runtime skill file (SKILL.md) belongs in the installed output; the
  # plugin/marketplace metadata is for other install paths.
  src = fetchFromGitHub {
    owner = "blader";
    repo = "humanizer";
    rev = "1b48564898e999219882660237fde01bf4843a0f";
    hash = "sha256-3+LoQ18+lcMxuEz8TLro0haScrgv3yJ6lDpMvU1qL3M=";
  };
in
  runCommandLocal "humanizer-skill" {
    meta = {
      description = "Humanizer skill for Claude Code: remove signs of AI-generated writing";
      homepage = "https://github.com/blader/humanizer";
      license = lib.licenses.mit;
    };
  } ''
    mkdir -p $out
    cp ${src}/SKILL.md $out/
  ''
