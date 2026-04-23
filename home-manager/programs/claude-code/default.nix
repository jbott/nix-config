{pkgs, ...}: let
  statusLine = pkgs.writeShellScript "claude-code-statusline" ''
    input=$(cat)
    jq() { ${pkgs.jq}/bin/jq "$@"; }

    model=$(echo "$input" | jq -r '.model.id // .model.display_name // "unknown"')
    pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
    window=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

    if [ -n "$pct" ] && [ "$window" -gt 0 ]; then
      # Derive used from window * pct: current_usage.input_tokens reports only
      # the last call's uncached portion, which is misleading with prompt caching.
      used_k=$(awk -v w="$window" -v p="$pct" 'BEGIN { printf "%d", (w * p / 100) / 1000 }')
      printf "%s  ctx: %dk / %dk (%.0f%%)" "$model" "$used_k" "$((window / 1000))" "$pct"
    else
      echo "$model"
    fi
  '';
in {
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    skills = {
      jj = ./skills/jj;
      jj-surgeon = "${pkgs.jj-hunk-tool.src}/skills/jj-surgeon";
    };

    settings = {
      includeCoAuthoredBy = false;
      model = "opus[1m]";
      autoCompactWindow = 400000;
      alwaysThinkingEnabled = true;
      skipDangerousModePermissionPrompt = true;
      spinnerTipsEnabled = false;
      statusLine = {
        type = "command";
        command = "${statusLine}";
      };
      env = {
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
        CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
        DISABLE_AUTOUPDATER = "1";
        DISABLE_INSTALLATION_CHECKS = "1";
      };
    };
  };
}
