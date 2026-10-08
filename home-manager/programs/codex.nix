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

  # Items shown in the TUI footer. Run `/statusline` inside codex to preview
  # the full list of identifiers.
  statusLine = [
    "model-with-reasoning"
    "context-remaining"
    "used-tokens"
    "context-window-size"
    "git-branch"
    "current-dir"
  ];

  # config.toml stays mutable because codex writes trust levels and other
  # settings into it, so only this key is patched in place. tomlkit keeps the
  # rest of the file's formatting intact.
  setCodexStatusLine =
    pkgs.writers.writePython3Bin "set-codex-status-line" {
      libraries = [pkgs.python3Packages.tomlkit];
    } ''
      import json
      import os
      import sys
      import tomlkit

      path = os.path.expanduser("~/.codex/config.toml")
      os.makedirs(os.path.dirname(path), exist_ok=True)
      try:
          with open(path) as f:
              doc = tomlkit.parse(f.read())
      except FileNotFoundError:
          doc = tomlkit.document()

      doc.setdefault("tui", tomlkit.table())["status_line"] = json.loads(
          sys.argv[1]
      )

      with open(path, "w") as f:
          f.write(tomlkit.dumps(doc))
    '';
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

  home.activation.codexStatusLine = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${lib.getExe setCodexStatusLine} ${lib.escapeShellArg (builtins.toJSON statusLine)}
  '';
}
