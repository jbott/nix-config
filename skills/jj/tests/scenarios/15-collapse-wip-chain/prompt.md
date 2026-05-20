The current stack on top of trunk is:

```
@      (empty)
wip3   wip: stop
wip2   wip: tick
wip1   wip: register_job
A      services/cron: add scheduler skeleton
trunk
```

You want to publish this work, but the three `wip: ...` commits should be
collapsed into a single descriptive commit. **A must be preserved** — it's
already a clean commit and shouldn't be absorbed into anything.

Change-ids are recorded in `.change-ids` for convenience.

**Your task:** collapse `wip1`, `wip2`, `wip3` into a single commit on top
of A, with a proper project-prefix description. The result should be:

```
@        (empty)
single   services/cron: ...
A        services/cron: add scheduler skeleton  (unchanged)
trunk
```

When done, briefly report:
1. The exact `jj` commands you ran (in order)
2. Confirm: A still exists with its original description, and there's
   exactly one commit between A and `@`
