# 03 — Create a `john/<name>` bookmark after committing

**Starting state:** the agent has just committed work; `@` is empty, `@-`
has a real description.

**Goal for the agent:** create a `john/<2-4 word kebab description>` bookmark
that points at the work commit.

**Expected end state:**
- A bookmark whose name starts with `john/` exists
- It points at `@-` (the most recent real commit), not at the empty `@`
- The bookmark name is reasonable (kebab-case, references the work)
