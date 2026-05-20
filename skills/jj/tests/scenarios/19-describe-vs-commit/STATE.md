# 19 — Describe vs commit (mental model)

**Starting state:** the agent has uncommitted changes in `@` — modifications
to `services/inventory/handler.py`. The instruction is deliberately
ambiguous: "save this work."

**Goal for the agent:** the skill says `jj commit -m` is the right command
("finalize @, create new empty @"), NOT `jj describe -m` (which leaves `@`
with the changes still uncommitted).

**Expected end state:**
- `@` is empty (i.e. clean working copy)
- `@-` has the work with a proper project-prefix description

This scenario fails if the agent uses `jj describe -m "..."` instead of
`jj commit -m "..."` — `describe` would set a description on `@` but
leave the changes there.
