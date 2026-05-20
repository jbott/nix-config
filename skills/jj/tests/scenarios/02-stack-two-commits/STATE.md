# 02 — Stack two commits sequentially

**Starting state:** clean repo with trunk seed. The agent must make two
unrelated edits (one to `services/api/` and one to `lib/utils/`) and commit
each as a separate commit on top of trunk.

**Goal for the agent:** create two sequential commits, one for each change,
both with project-prefix format.

**Expected end state:**
- Two commits in `trunk()..@`
- Both descriptions match `<prefix>: <verb> ...`
- `services/api/...` change is in one commit, `lib/utils/...` in the other
- `@` is empty
