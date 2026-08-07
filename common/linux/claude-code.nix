{pkgs, ...}: {
  # Claude Code reads system-scope policy from /etc/claude-code on Linux.
  # See common/claude-code/managed-settings.nix for why these settings live in
  # the managed scope instead of home-manager's ~/.claude/settings.json.
  environment.etc."claude-code/managed-settings.json".source =
    import ../claude-code/managed-settings.nix {inherit pkgs;};
}
