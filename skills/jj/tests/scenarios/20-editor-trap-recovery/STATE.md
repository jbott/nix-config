# 20 — Editor trap: recover from `$EDITOR` failure

**Starting state:** uncommitted changes in `@`. `JJ_EDITOR` is set to a
script that errors immediately with a helpful message, simulating the
structural guard in the Claude Code config. If the agent runs a `jj`
command without `-m`, the trap fires and the command fails.

**Goal for the agent:** commit the work successfully, even if their first
attempt hits the trap. The skill (and the trap's error message) tells them
to pass `-m`.

**Expected end state:**
- `@` is empty (commit succeeded eventually)
- `@-` has a project-prefix description
- The repo has at least one `jj describe` or `jj commit` operation in its
  op log that exited non-zero (the trap firing), followed by a successful
  one (this is informational; the verify script doesn't enforce it)
