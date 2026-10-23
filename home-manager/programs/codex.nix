{pkgs, ...}: let
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
in {
  programs.codex = {
    enable = true;
    # Sourced from the llm-agents overlay (see flake.nix) to track upstream
    # releases alongside claude-code, rather than nixpkgs' snapshot.
    package = pkgs.codex;

    # Codex writes trust levels and other preferences back into config.toml,
    # so declared settings are merged into the writable file at activation
    # rather than linked from the store.
    mutableSettings = true;
    settings.tui.status_line = statusLine;

    # Same set claude-code gets; home-manager symlinks each entry individually
    # into ~/.codex/skills, so codex's bundled .system skills stay put.
    skills = import ../agent-skills.nix {inherit pkgs;};
  };
}
