# 07 — Move a commit out of the stack onto trunk

**Starting state:** stack `trunk → A → B → C → @`. B is actually unrelated to
A and C — it should live directly on trunk, not in this stack.
- A: `services/api: scaffold service` (adds `services/api/handler.py`)
- B: `docs: fix typo in README` (modifies `README.md`)
- C: `services/api: add health check` (adds `services/api/health.py`)

**Goal for the agent:** move B so it's a child of `trunk()` directly. A and
C should remain stacked together (without B). Use `-r` (not `-s`) so C
doesn't go with B.

**Expected end state:**
- B is a child of `trunk()` (its parent is the trunk seed)
- A and C are stacked on trunk, in that order, with `@` empty on top
- README.md changes are present only in B's branch, not in the A/C stack
