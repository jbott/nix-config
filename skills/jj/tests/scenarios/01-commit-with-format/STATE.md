# 01 — Commit working-copy changes with project-prefix format

**Starting state:** repo with `services/api/handler.py` and `services/api/README.md`
modified in the working copy. No description on `@`.

**Goal for the agent:** commit the changes.

**Expected end state:**
- `@-` has a description matching `services/api: <lowercase verb> ...`
- `@` is empty
- Both modified files are in `@-`
