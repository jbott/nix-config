# 13 — Squash `@` into `@-`

**Starting state:** `@-` is a described commit ("services/api: add health
check") with one file. `@` has additional changes (modifies the same file
to add error handling) but no description.

**Goal for the agent:** combine `@`'s changes into `@-`, so the result is a
single commit with both the original feature and the additional changes.

**Expected end state:**
- Same stack height as before (the squash didn't add or remove commits)
- `@-` description is the original one (or an updated combined one)
- `@-` contains both the initial file content AND the additional changes
- `@` is empty
