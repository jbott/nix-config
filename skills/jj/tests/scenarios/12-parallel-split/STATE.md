# 12 — Split with `-p` to create parallel siblings

**Starting state:** one commit at `@-` titled "wip: independent additions"
that adds two completely independent files:

- `services/foo/handler.py`
- `services/bar/handler.py`

These are independent — neither depends on the other — so they should be
PARALLEL siblings, not stacked.

**Goal for the agent:** split into two commits that are **siblings of each
other** (both children of the previous trunk commit), not parent/child.

**Expected end state:**
- Two commits exist, both with project-prefix descriptions
- They are siblings: both have the same parent (the trunk seed)
- `@` is now a merge commit of both, OR `@` is a child of one of them with
  the other commit reachable via a sibling branch
