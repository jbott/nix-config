# 10 — Split one commit into three commits by file

**Starting state:** one commit at `@-` titled "wip: dump of changes" that
touches 5 files belonging to 3 logical groups:

- Feature X: `services/x/{handler,router}.py`
- Bug Y: `services/y/{validator,tests}.py`
- Refactor: `lib/common/helpers.py`

**Goal for the agent:** split this commit into three separate, well-described
commits. The exact ordering of the three resulting commits in the stack is
not required, but each must contain only its own files.

**Expected end state:**
- 3 real commits in `trunk()..@` (plus empty `@`) = stack height 4
- Each commit has a project-prefix description
- File groupings stay together — no commit mixes files from two groups
