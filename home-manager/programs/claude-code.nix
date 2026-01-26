{
  programs.claude-code = {
    enable = true;

    skillsDir = ./claude-code/skills;

    settings = {
      includeCoAuthoredBy = false;
      model = "opus";
      alwaysThinkingEnabled = true;
      spinnerTipsEnabled = false;
      env = {
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
        CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
        DISABLE_AUTOUPDATER = "1";
        DISABLE_INSTALLATION_CHECKS = "1";
      };
    };
  };
}
