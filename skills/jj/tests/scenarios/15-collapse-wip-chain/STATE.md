# 15 — Collapse three WIP commits into one, preserving the pre-WIP commit

**Starting state:** stack `trunk → A → wip1 → wip2 → wip3 → @` where:
- A: `services/cron: add scheduler skeleton` (a real, pre-WIP commit)
- wip1, wip2, wip3: three WIP commits that progressively build out the same
  feature

**Goal for the agent:** collapse `wip1 → wip2 → wip3` into a single commit
on top of A. A must be preserved unchanged.

**Expected end state:**
- Stack: `trunk → A → single → @`
- A's description is unchanged
- The `single` commit contains all the changes from wip1 + wip2 + wip3
- A is NOT consumed (the recipe's footgun)
- Stack height: trunk()..@ = A + single + @ = 3
