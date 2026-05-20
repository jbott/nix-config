There is a megamerge `M` on top of trunk that merges two feature branches
(`john/feature-a` and `john/feature-b`). On top of `M` sits a single
non-empty commit `services/c: add handler` adding `services/c/handler.py`.
The empty working copy `@` is above that commit.

```
@                              (empty)
○  services/c: add handler     (services/c/handler.py)
M  merge: integration          (merge of trunk, feature-a, feature-b)
├─○  services/b: add handler   john/feature-b
├─○  services/a: add handler   john/feature-a
trunk  (main)
```

**Your task:** use the skill's megamerge alias to consolidate `services/c`
into the megamerge as a **new parent branch** — in one command, not by
hand-rebasing. After the alias runs, the megamerge should have a third
non-trunk parent containing `services/c/handler.py`, and the commit slot
above the merge should be empty.

When done, briefly report:
1. The exact `jj` command(s) you ran
2. The new number of parents of the megamerge (the `closest_merge(@)`)
3. Confirm: `services/c/handler.py` is reachable from one of the merge's
   parents and the slot above the merge is empty
