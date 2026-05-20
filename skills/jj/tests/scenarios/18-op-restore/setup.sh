#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"

init_repo

mkdir -p src

# Build the "real" stack: A, B, C.
echo "a = 1" > src/a.py
commit_with "src/a: add a"
echo "b = 2" > src/b.py
commit_with "src/b: add b"
B_change=$(jj log -r '@-' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
echo "c = 3" > src/c.py
commit_with "src/c: add c"

# Sanity: 3 real commits + empty @ = stack height 4.
got_h=$(stack_height)
[ "$got_h" = "4" ] || { echo "SETUP ERROR: pre-abandon stack height $got_h, expected 4"; exit 2; }

# Now corrupt: abandon B.
jj abandon "$B_change" >/dev/null

# After abandon: 2 real commits + empty @ = stack height 3.
got_h=$(stack_height)
[ "$got_h" = "3" ] || { echo "SETUP ERROR: post-abandon stack height $got_h, expected 3"; exit 2; }
assert_clean_working_copy

echo "Setup complete: $REPO_ROOT"
echo "Stack: A -> C -> @ (B was abandoned). Agent must op-restore to recover B."
