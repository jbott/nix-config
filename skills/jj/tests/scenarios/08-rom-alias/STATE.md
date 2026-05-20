# 08 — Rebase current stack onto updated trunk via `jj rom`

**Starting state:** the stack is rooted on the OLD trunk position. Since then,
`main` has advanced (a new commit was added to it). The agent should rebase
their stack onto the new trunk.
- Stack (on old trunk): A `services/api: add /v1/users`
- New trunk commit (not in stack): `docs: add CONTRIBUTING`

**Goal for the agent:** use the `jj rom` alias to rebase the stack onto the
updated trunk.

**Expected end state:**
- Stack's parent is now the new trunk tip (`docs: add CONTRIBUTING`)
- A's content is preserved (`services/api/users.py` exists at `@-`)
- `@` is empty
