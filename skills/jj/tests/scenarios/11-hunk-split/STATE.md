# 11 — Split a file by hunk via `jj-hunk-tool`

**Starting state:** one commit at `@-` titled "src/api: changes" that modifies
a single file `src/api.py` with two clearly separated logical changes:

- Lines 5-15: a bugfix in `retry_with_backoff`
- Lines 30-40: an unrelated style cleanup in `format_response`

**Goal for the agent:** split this commit into two commits, one per logical
change, using `jj-hunk-tool` for the hunk-level operation (since `jj split`
on file granularity can't split within a file).

**Expected end state:**
- 2 real commits in `trunk()..@` (plus empty `@`) = stack height 3
- The bugfix commit contains the lines 5-15 change only
- The cleanup commit contains the lines 30-40 change only
- Both commits have project-prefix descriptions
