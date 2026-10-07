{
  lib,
  pkgs,
  ...
}: let
  disableDaemonUpdater = pkgs.writeShellApplication {
    name = "disable-codex-daemon-updater";
    runtimeInputs = [pkgs.jq];
    text = ''
      settings_file="$HOME/.codex/app-server-daemon/settings.json"
      mkdir -p "$(dirname "$settings_file")"
      touch "$settings_file"
      # Capture before writing so a jq failure leaves the file untouched.
      updated=$(jq --slurp '(.[0] // {}) | .updater.autoUpdateEnabled = false' "$settings_file")
      echo "$updated" > "$settings_file"
    '';
  };
in {
  programs.codex = {
    enable = true;
    # Sourced from the llm-agents overlay (see flake.nix) to track upstream
    # releases alongside claude-code, rather than nixpkgs' snapshot.
    package = pkgs.codex;

    # Same set claude-code gets; home-manager symlinks each entry individually
    # into ~/.codex/skills, so codex's bundled .system skills stay put.
    skills = import ../agent-skills.nix {inherit pkgs;};
  };

  home.activation.codexDaemonUpdater = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${lib.getExe disableDaemonUpdater}
  '';
}
