{
  lib,
  fetchFromGitHub,
}: let
  src = fetchFromGitHub {
    owner = "ed3dai";
    repo = "ed3d-plugins";
    rev = "998845ddf404fa0d184a9043576f9bce4395de80";
    hash = "sha256-s6d5em01MUGrljDGMM+auR7P5IKicinqQl/jNolofJE=";
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
