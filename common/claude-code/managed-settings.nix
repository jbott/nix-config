# Claude Code managed (system-scope) settings.
#
# Claude Code rewrites its user-scope settings file (`~/.claude/settings.json`)
# at runtime whenever a preference changes — picking a model, toggling always-on
# thinking, granting a persistent permission. A home-manager symlink into the
# read-only store therefore gets replaced by a real file, and the next
# `darwin-rebuild switch` aborts with "would be clobbered".
#
# Managed settings sit in the one scope Claude Code never writes to, so nix and
# Claude Code stop fighting over a single file. The trade is precedence:
# managed outranks project `.claude/settings.json`, so nothing here can be
# overridden per-repo. Keep this to machine policy — hooks, env, the status
# line — and leave genuine preferences to the user scope.
#
# Consumed by common/darwin/claude-code.nix and common/linux/claude-code.nix,
# which differ only in where the file has to land.
{pkgs}: let
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

  # WorktreeCreate hook: claude pipes `{"name": "..."}` on stdin and expects the
  # absolute worktree path on stdout to cd into. `jjw new` owns the path
  # convention and the main-workspace anchoring (see overlay/pkgs/jjw), and is
  # idempotent, so an existing workspace is reused and `yolo --worktree <name>`
  # resumes.
  worktreeCreateHook = pkgs.writeShellScript "claude-code-hook-WorktreeCreate" ''
    set -euo pipefail
    name=$(${pkgs.jq}/bin/jq -r '.name')
    exec ${pkgs.jjw}/bin/jjw -R "$CLAUDE_PROJECT_DIR" new "$name"
  '';

  # Structural guard: jj reads JJ_EDITOR (cli/src/config.rs) and uses it as the
  # description editor. Claude has no terminal, so any interactive editor hangs.
  # Point JJ_EDITOR at a script that errors with a clear hint instead.
  # Note: this does NOT cover the diff editor (ui.diff-editor / :builtin TUI);
  # those traps are documented in the jj skill.
  jjEditorTrap = pkgs.writeShellScript "claude-code-jj-editor-trap" ''
    cat >&2 <<'EOF'
    jj invoked the description editor, but Claude cannot use interactive editors.
    Re-run the command with -m "<message>" (or --stdin for multi-line).
    For `jj squash`, pass --use-destination-message (-u) to keep the existing message.
    EOF
    exit 1
  '';

  # PostToolUse snapshot hook: `jj util snapshot` is the dedicated command for
  # this (jj FAQ: "manually trigger a snapshot ... for scripting"). Captures
  # Claude's edits as working-copy state — recoverable via `jj op log` /
  # `jj op restore`. Silently no-ops outside jj repos (snapshot exits 1 with
  # "no jj repo"; `|| true` swallows it).
  jjSnapshotHook = pkgs.writeShellScript "claude-code-hook-jj-snapshot" ''
    ${pkgs.jujutsu}/bin/jj util snapshot --quiet || true
  '';

  # `|| true` because this also fires for worktrees jj never tracked, and
  # `jjw rm` exits non-zero on an unknown workspace.
  worktreeRemoveHook = pkgs.writeShellScript "claude-code-hook-WorktreeRemove" ''
    set -euo pipefail
    worktree_path=$(${pkgs.jq}/bin/jq -r '.worktree_path')
    ${pkgs.jjw}/bin/jjw -R "$CLAUDE_PROJECT_DIR" rm "$(basename "$worktree_path")" || true
  '';
in
  (pkgs.formats.json {}).generate "claude-code-managed-settings.json" {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";

    includeCoAuthoredBy = false;
    autoCompactWindow = 500000;
    skipDangerousModePermissionPrompt = true;
    spinnerTipsEnabled = false;
    # Keep `!` bash commands context-only (the pre-2.1.157 behavior) instead of
    # having Claude auto-respond to their output.
    respondToBashCommands = false;

    statusLine = {
      type = "command";
      command = "${statusLine}";
    };

    hooks = {
      PostToolUse = [
        {
          matcher = "Edit|Write|MultiEdit|NotebookEdit|Bash";
          hooks = [
            {
              type = "command";
              command = "${jjSnapshotHook}";
              timeout = 10;
            }
          ];
        }
      ];
      WorktreeCreate = [
        {
          hooks = [
            {
              type = "command";
              command = "${worktreeCreateHook}";
              timeout = 60;
            }
          ];
        }
      ];
      WorktreeRemove = [
        {
          hooks = [
            {
              type = "command";
              command = "${worktreeRemoveHook}";
            }
          ];
        }
      ];
    };

    env = {
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
      CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
      DISABLE_AUTOUPDATER = "1";
      DISABLE_INSTALLATION_CHECKS = "1";
      JJ_EDITOR = "${jjEditorTrap}";
    };
  }
