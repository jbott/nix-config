# 14 — Squash a fixup into a non-adjacent ancestor

**Starting state:** stack `trunk → A → B → C → @` where:
- A: `services/api: add /users endpoint` (adds `services/api/users.py` with a
  typo: `def liste_users` instead of `def list_users`)
- B: `services/api: add /orders endpoint`
- C: `services/api: add /products endpoint`
- `@`: contains a fixup for the typo in A (changes `liste_users` to
  `list_users`)

**Goal for the agent:** move the typo fix from `@` into commit A, where the
typo was originally introduced. The intermediate commits B and C should
remain unchanged.

**Expected end state:**
- A now contains `def list_users` (no typo)
- B and C remain in the stack with their original descriptions
- `@` is empty
- Stack height unchanged: 5 = trunk + A + B + C + @ → trunk + A' + B + C + @ = 5
  (counting trunk()..@: A' + B + C + @ = 4)
