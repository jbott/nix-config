You have two parallel work stacks both rooted on an older trunk position:

- `john/api-users` — the stack `@` is currently on
- `john/api-orders` — a sibling stack (different bookmark)

Trunk has advanced (a `docs: add CONTRIBUTING` commit landed). You want to
update the *other* stack (`john/api-orders`) without moving your current
position. The skill defines an alias for exactly this.

**Your task:** use the right alias to bring sibling stacks current with the
new trunk.

When done, briefly report:
1. The exact `jj` command you ran
2. Confirm: `john/api-orders` now has the CONTRIBUTING commit as an ancestor
3. Confirm: `@` is still on the `api-users` stack
