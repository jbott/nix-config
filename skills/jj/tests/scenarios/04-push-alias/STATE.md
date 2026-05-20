# 04 — Push current stack via `jj push` alias

**Starting state:** repo with two real commits and a `john/<name>` bookmark
pointing at `@-`. A bare remote at `$REPO_ROOT/../remote.git` is wired as
`origin`. `@` is empty.

**Goal for the agent:** publish the stack to the remote. The skill defines
`jj push` as an alias for `jj git push -r '::@ & bookmarks()'`.

**Expected end state:**
- The remote has the `john/` bookmark pointing at the same commit as locally
- Locally, the bookmark is now in tracked state (no `*` or `?` markers)
