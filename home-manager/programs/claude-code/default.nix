{pkgs, ...}: {
  # Deliberately no `settings` here. Claude Code rewrites ~/.claude/settings.json
  # whenever a preference changes at runtime, which replaces home-manager's
  # symlink with a real file and makes the next switch fail with "would be
  # clobbered". Everything nix wants to pin now lives in the managed scope —
  # see common/claude-code/managed-settings.nix — and the user-scope file is
  # left entirely to Claude Code.
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    skills = import ../../agent-skills.nix {inherit pkgs;};

    plugins = {
      inherit (pkgs.ed3d-plugins.plugins) basic-agents research-agents extending-claude;
    };
  };
}
