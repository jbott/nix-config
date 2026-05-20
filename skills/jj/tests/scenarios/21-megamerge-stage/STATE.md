# 21 — Megamerge: `jj stage` folds work into the merge

**Starting state:** a megamerge `M` on top of trunk, built from two sibling
branches (`john/feature-a` and `john/feature-b`). On top of `M` is one
non-empty commit `services/c: add handler`. `@` is empty above that.

```
@                              (empty)
○  services/c: add handler     (services/c/handler.py — should become a new branch)
M  merge: integration          (3-way merge of trunk + feature-a + feature-b)
├─○  services/b: add handler   bookmark john/feature-b
├─○  services/a: add handler   bookmark john/feature-a
trunk  (main)
```

**Goal for the agent:** use `jj stage` to consolidate the `services/c`
commit as a new parent branch of the megamerge in one step.

**Expected end state:**
- The megamerge has **at least 3 non-trunk parents** (feature-a, feature-b,
  and the new feature-c branch).
- One of the merge's parents contains `services/c/handler.py`.
- The original `services/c: add handler` position above the merge is now
  empty (its content moved into the merge as a new parent).
- `@` is still empty above the merge.
