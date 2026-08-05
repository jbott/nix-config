{pkgs, ...}: {
  programs.codex = {
    enable = true;
    # Sourced from the llm-agents overlay (see flake.nix) to track upstream
    # releases alongside claude-code, rather than nixpkgs' snapshot.
    package = pkgs.codex;

    # Same set claude-code gets; home-manager symlinks each entry individually
    # into ~/.codex/skills, so codex's bundled .system skills stay put.
    skills = import ../agent-skills.nix {inherit pkgs;};
  };
}
