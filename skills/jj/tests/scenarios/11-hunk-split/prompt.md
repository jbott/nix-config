There's a commit "src/api: changes" at `@-` that mixes two unrelated changes
in `src/api.py`:

1. A bugfix near the top of the file: exponential backoff in
   `retry_with_backoff` (was constant, now grows). Also adds `import time`.
2. A style cleanup near the bottom: `format_response` switched from a dict
   literal to `dict(...)` call.

**Your task:** split this single commit into two commits using the
hunk-level tool. The bugfix and the cleanup must end up in separate
commits, both with proper project-prefix descriptions.

When done, briefly report:
1. The exact commands you ran
2. The final stack (descriptions bottom-up)
