{
  lib,
  runCommandLocal,
  fetchFromGitHub,
}: let
  # Upstream: https://github.com/twostraws/swiftui-agent-skill — Paul Hudson's
  # SwiftUI review skill. Pinned to a commit; bump rev + hash to update. Only
  # the top-level swiftui-pro/ skill (SKILL.md + references/) belongs in the
  # installed output; its nested skills/ copy and plugin/agents metadata are for
  # other install paths.
  src = fetchFromGitHub {
    owner = "twostraws";
    repo = "swiftui-agent-skill";
    rev = "be297ff80dddec529af1f9b1f1f114aab6c9d11c";
    hash = "sha256-n3pcnUfT9h5h29eV4Zy5rYcf1/MKnVKh/t96tCASoNs=";
  };
in
  runCommandLocal "swiftui-pro-skill" {
    meta = {
      description = "SwiftUI Pro skill for Claude Code: review SwiftUI code for modern API, maintainability, and performance";
      homepage = "https://github.com/twostraws/swiftui-agent-skill";
      license = lib.licenses.mit;
    };
  } ''
    mkdir -p $out
    cp ${src}/swiftui-pro/SKILL.md $out/
    cp -r ${src}/swiftui-pro/references $out/
  ''
