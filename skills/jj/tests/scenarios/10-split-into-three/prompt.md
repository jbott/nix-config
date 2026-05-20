There's a single "wip" commit at `@-` containing 5 files in 3 logical
groups:

- Feature X work: `services/x/handler.py`, `services/x/router.py`
- Bug Y fix: `services/y/validator.py`, `services/y/tests.py`
- Unrelated refactor: `lib/common/helpers.py`

**Your task:** split this into three separate commits with proper
project-prefix descriptions. Each commit should contain only the files for
its group — no mixing.

When done, briefly report:
1. The exact `jj` commands you ran in order
2. The final stack (descriptions bottom-up)
