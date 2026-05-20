The current stack is:

```
@   (typo fix in the file from A; no description yet)
C   services/api: add /products endpoint
B   services/api: add /orders endpoint
A   services/api: add /users endpoint    (has a typo: `liste_users` instead of `list_users`)
trunk
```

The fix in `@` belongs in A — that's where the typo was introduced. B and C
should be left untouched.

**Your task:** move the fix from `@` into A. After you're done, A should
contain `def list_users` (no typo), and B and C should still be in the
stack with their original descriptions.

To find A's change-id, run `jj log` or read `.A-change-id` in the repo.

When done, briefly report:
1. The exact `jj` command you ran
2. Confirm: A now has the fixed function and `@` is empty
