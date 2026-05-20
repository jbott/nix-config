# 05 — Summarize a large diff

**Starting state:** repo with a single commit on top of trunk that touches 8
files and adds ~600 lines of code (a "large" diff by the skill's >200-line
threshold). `@` is empty on top of it.

**Goal for the agent:** describe what the commit does. The skill says that
for diffs >5 files or >200 lines, the agent should dispatch a haiku subagent
to summarize rather than reading the whole diff itself.

**Expected end state:** the agent produces a coherent description of the
change. The verifier accepts any summary that mentions at least 2 of the
introduced modules (auth, billing, search, etc.).
