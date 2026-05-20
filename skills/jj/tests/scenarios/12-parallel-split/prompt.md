There's a "wip" commit at `@-` that adds two independent service handlers
(`services/foo/handler.py` and `services/bar/handler.py`). They have no
dependency on each other — they should be **parallel siblings**, not
stacked.

**Your task:** split into two sibling commits (both children of the
previous trunk commit), one per service, each with a proper project-prefix
description.

When done, briefly report:
1. The exact `jj split` command(s) you ran
2. Confirm the two resulting commits are siblings (same parent), not
   parent/child
