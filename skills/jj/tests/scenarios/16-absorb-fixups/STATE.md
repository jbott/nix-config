# 16 — Absorb scattered fixups by blame

**Starting state:** stack `trunk → A → B → C → @` where:
- A: `services/api: add /v1/users` (adds `users.py`)
- B: `services/api: add /v1/orders` (adds `orders.py`)
- C: `services/api: add /v1/products` (adds `products.py`)
- `@`: contains small fixups touching lines that originate from each of
  A, B, and C (one fix in each file)

**Goal for the agent:** distribute the fixups from `@` into their respective
origin commits using `jj absorb` (or `jj-hunk-tool absorb`). Each origin
commit should pick up the change that touches its file.

**Expected end state:**
- A, B, C each contain their original code AND the fixup line that
  originated there
- `@` is empty (all fixups absorbed)
- Stack height unchanged: trunk()..@ = A + B + C + @ = 4
