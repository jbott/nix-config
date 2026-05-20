# 18 — Recover from a bad rewrite via `jj op restore`

**Starting state:** the agent's "real" work was a stack of 3 commits, but
then someone (the setup script) ran `jj abandon` on the middle commit by
mistake. Now the stack is `trunk → A → C → @` (B is gone). The work in B
is no longer reachable in `@`'s ancestry.

The agent must use the operation log to restore the state from before the
mistake.

**Goal for the agent:** find the operation just before the abandon and
restore to it, so the stack is `trunk → A → B → C → @` again.

**Expected end state:**
- Stack height = trunk + A + B + C + @ → trunk()..@ = 4
- All three of A, B, C exist in the stack in correct order
- All three files (`a.py`, `b.py`, `c.py`) exist at `@-`
