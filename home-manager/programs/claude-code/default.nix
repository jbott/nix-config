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

  # WorktreeCreate hook: claude pipes `{"name": "..."}` on stdin; we create
  # a jj workspace at <parent-of-main-repo>/.worktrees/<main-repo>/<name> and
  # print the absolute path on stdout for claude to cd into. Keeping worktrees
  # beside the repo (not under .claude/) avoids nesting them inside the tracked
  # tree; the <main-repo> segment namespaces them so sibling repos sharing the
  # parent don't collide on a shared worktree name.
  #
  # We anchor to the MAIN workspace root, not $CLAUDE_PROJECT_DIR, because that
  # may itself be a worktree (claude launched inside one) — using it directly
  # would nest worktrees inside worktrees. jj's `$root/.jj/repo` is a directory
  # in the main workspace but a file pointing at <main>/.jj/repo in secondary
  # workspaces, so we follow it to recover the main root. If a workspace with
  # the requested name already exists, reuse it so `yolo --worktree <name>`
  # resumes. Source: https://github.com/kawaz/jj-worktree/issues/1
  worktreeCreateHook = pkgs.writeShellScript "claude-code-hook-WorktreeCreate" ''
    set -euo pipefail
    input=$(cat)
    name=$(${pkgs.jq}/bin/jq -r '.name' <<< "$input")
    ws_root=$(${pkgs.jujutsu}/bin/jj -R "$CLAUDE_PROJECT_DIR" workspace root)
    if [ -f "$ws_root/.jj/repo" ]; then
      repo_root=$(dirname "$(cd "$ws_root/.jj" && cd "$(dirname "$(cat repo)")" && pwd)")
    else
      repo_root="$ws_root"
    fi
    worktree_path="$(dirname "$repo_root")/.worktrees/$(basename "$repo_root")/$name"
    jj="${pkgs.jujutsu}/bin/jj -R $repo_root"
    if $jj workspace list -T 'name ++ "\n"' | grep -Fxq "$name"; then
      if [ ! -d "$worktree_path" ]; then
        echo "Error: jj workspace '$name' is tracked but $worktree_path is missing." >&2
        echo "Run 'jj workspace forget $name' to drop the stale entry, then retry." >&2
        exit 1
      fi
      echo "Reusing existing jj workspace '$name' at $worktree_path" >&2
    else
      mkdir -p "$(dirname "$worktree_path")"
      $jj workspace add "$worktree_path" >&2
    fi
    echo "$worktree_path"
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

  worktreeRemoveHook = pkgs.writeShellScript "claude-code-hook-WorktreeRemove" ''
    set -euo pipefail
    input=$(cat)
    worktree_path=$(${pkgs.jq}/bin/jq -r '.worktree_path' <<< "$input")
    workspace_name=$(basename "$worktree_path")
    if [ -d "$worktree_path" ]; then
      ${pkgs.jujutsu}/bin/jj -R "$CLAUDE_PROJECT_DIR" workspace forget "$workspace_name" 2>/dev/null || true
      rm -rf "$worktree_path"
    fi
  '';
in {
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    skills = {
      jj = "${pkgs.jj-skill}";
    };

    plugins = with pkgs.ed3d-plugins.plugins; [
      basic-agents
      plan-and-execute
      research-agents
      extending-claude
    ];

    settings = {
      includeCoAuthoredBy = false;
      model = "opus[1m]";
      autoCompactWindow = 500000;
      alwaysThinkingEnabled = true;
      skipDangerousModePermissionPrompt = true;
      spinnerTipsEnabled = false;
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
    };
  };
}
