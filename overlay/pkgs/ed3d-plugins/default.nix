{
  lib,
  fetchFromGitHub,
}: let
  src = fetchFromGitHub {
    owner = "ed3dai";
    repo = "ed3d-plugins";
    rev = "47257b5ead52972de667f8922f6cc4ec3af1d8cd";
    hash = "sha256-IbbapwbuXyYJLf+rE3mFoMw+WRvc4dOhpYO2h1ioWME=";
  };
  pluginNames = [
    "00-getting-started"
    "basic-agents"
    "extending-claude"
    "hook-claudemd-reminder"
    "hook-security-hardening"
    "hook-skill-reinforcement"
    "house-style"
    "plan-and-execute"
    "playwright"
    "research-agents"
    "session-reflection"
  ];
in
  src
  // {
    plugins = lib.listToAttrs (map (name: {
        inherit name;
        value = "${src}/plugins/ed3d-${name}";
      })
      pluginNames);
  }
