# Skills shared by every agent harness. claude-code (~/.claude/skills) and
# codex (~/.codex/skills) both read the same `<name>/SKILL.md` layout, so the
# set is defined once here and imported by both program modules to keep them
# from drifting.
#
# Claude Code plugins (see programs/claude-code) are deliberately not mirrored:
# their agents/ and commands/ are Claude-specific.
{pkgs}: {
  commit-scope = ../skills/commit-scope;
  herdr-core = "${pkgs.herdr-core}/share/skills/herdr-core/herdr-core";
  jj = "${pkgs.jj-skill}";
  humanizer = "${pkgs.humanizer-skill}";
  swiftui-pro = "${pkgs.swiftui-pro-skill}";
}
