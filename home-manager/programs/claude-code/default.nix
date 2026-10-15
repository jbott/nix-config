{pkgs, ...}: {
  # Deliberately no `settings` here. Everything nix wants to pin lives in the
  # managed scope — see common/claude-code/managed-settings.nix — so no
  # project's .claude/settings.json can override it, and the user-scope file is
  # left entirely to Claude Code. `mutableSettings` would also stop Claude Code
  # from clobbering a linked ~/.claude/settings.json, but it gives up that lock.
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    skills = import ../../agent-skills.nix {inherit pkgs;};

    plugins = {
      inherit (pkgs.ed3d-plugins.plugins) basic-agents research-agents extending-claude;
    };
  };
}
