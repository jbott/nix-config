You started a stack on top of trunk, then went to lunch. While you were out,
someone landed `docs: add CONTRIBUTING` directly on trunk. Your stack still
points at the old trunk position, so your work is now diverged.

**Your task:** bring your stack current with the updated trunk, using the
skill's preferred alias for "rebase current stack onto trunk".

When done, briefly report:
1. The exact `jj` command you ran
2. The new parent of your stack's bottom commit (should be the
   CONTRIBUTING commit)
