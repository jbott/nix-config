{pkgs, ...}: {
  programs.codex = {
    enable = true;
    # Sourced from the llm-agents overlay (see flake.nix) to track upstream
    # releases alongside claude-code, rather than nixpkgs' snapshot.
    package = pkgs.codex;
  };
}
