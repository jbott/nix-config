# 06 — Reorder commits B and C in a stack

**Starting state:** stack `trunk → A → B → C → @` (empty `@`). Each of A/B/C
touches a distinct file with a distinct description:
- A: `services/api: add ping endpoint` (adds `services/api/ping.py`)
- B: `services/api: add auth middleware` (adds `services/api/auth.py`)
- C: `services/api: add rate limit` (adds `services/api/ratelimit.py`)

**Goal for the agent:** swap B and C so the new order is `trunk → A → C → B → @`.

**Expected end state:**
- Stack height unchanged (4 = trunk seed + A + C + B + @)
- Order from bottom up: A, then C, then B
- All three files still present in `@-`
- No conflicts
