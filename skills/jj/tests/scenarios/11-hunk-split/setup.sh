#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"

init_repo

# Baseline file in the trunk seed.
mkdir -p src
cat > src/api.py <<'EOF'
"""API module."""

# 1: header
def retry_with_backoff(fn, attempts=3, delay=1.0):
    last = None
    for i in range(attempts):
        try:
            return fn()
        except Exception as e:
            last = e
            time.sleep(delay)
    raise last

# 15: divider



# 20: more divider



# 25: still more
def format_response(body):
    return {
      "status": "ok",
      "body": body
    }


# 35: ending
def helper():
    return None
EOF
commit_with "src/api: scaffold api module"

# Now make two changes in the same file, then commit them as one big "changes" commit.
# Change 1 (bugfix, ~lines 5-15): import time at the top, fix delay growth.
cat > src/api.py <<'EOF'
"""API module."""
import time

# 1: header
def retry_with_backoff(fn, attempts=3, delay=1.0):
    last = None
    cur = delay
    for i in range(attempts):
        try:
            return fn()
        except Exception as e:
            last = e
            time.sleep(cur)
            cur *= 2
    raise last

# 15: divider



# 20: more divider



# 25: still more
def format_response(body):
    # cleanup: use modern dict literal style
    return dict(status="ok", body=body)


# 35: ending
def helper():
    return None
EOF
commit_with "src/api: changes"

# Stack height: scaffold + "changes" + empty @ = 3.
assert_starting_state 3 clean

echo "Setup complete: $REPO_ROOT"
echo "Single 'changes' commit at @- has two logical hunks in src/api.py."
