# 17 — Resolve a conflict after rebase

**Starting state:** trunk has advanced. The new trunk tip touches the same
lines of `src/config.py` that the agent's pending stack also touches.
Rebasing the stack onto the new trunk will produce a conflict.

- Old trunk had `src/config.py` with `MAX_RETRIES = 3`
- New trunk: `docs/team: change MAX_RETRIES to 5` (`MAX_RETRIES = 5`)
- Agent's stack on old trunk: `src/config: change MAX_RETRIES to 10`

**Goal for the agent:** rebase the stack onto the new trunk and resolve the
resulting conflict, ending up with `MAX_RETRIES = 10` (preferring the
agent's value). The skill says to resolve conflicts by reading the file
and editing out the markers directly.

**Expected end state:**
- Agent's stack rebased onto the new trunk (parent of the stack tip is the
  new trunk commit)
- `src/config.py` at `@-` has `MAX_RETRIES = 10` (clean, no conflict
  markers)
- No conflicts present in the repo (`jj log -r 'conflicts()'` empty)
