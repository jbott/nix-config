# 09 — Bring sibling stacks current via `jj restack`

**Starting state:** trunk has advanced. There are two separate work stacks
that branched from the OLD trunk — one is current (`@` is on it), the other
is a sibling stack (different bookmark, also rooted on old trunk).

- Current stack (where `@` lives): `john/api-users` — has 1 commit
- Sibling stack: `john/api-orders` — has 1 commit, rooted on old trunk

**Goal for the agent:** use `jj restack` to rebase the *sibling* stack
(`john/api-orders`) onto the new trunk. The current stack stays where it is.

**Expected end state:**
- `john/api-orders` bookmark now points at a commit whose ancestor is the
  new trunk tip (`docs: add CONTRIBUTING`)
- Current stack (`john/api-users`) unchanged
- `@` is empty
