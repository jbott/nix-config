#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"

init_repo

# Pre-create directories with placeholder files so paths are obvious.
mkdir -p services/api lib/utils
cat > services/api/handler.py <<'EOF'
def handle(req):
    return {"status": "ok"}
EOF
cat > lib/utils/dates.py <<'EOF'
def parse_iso(s):
    # FIXME: doesn't handle timezone suffix
    return s
EOF

commit_with "init: scaffold services/api and lib/utils"
# Make the scaffold part of trunk so the agent's commits land directly on
# trunk() and don't get counted in the verify's stack-height check.
jj bookmark set main -r '@-' >/dev/null

# Starting state: empty @ on top of trunk (scaffold), nothing in trunk()..@.
assert_starting_state 1 clean
echo "Setup complete: $REPO_ROOT"
echo "@ is empty on top of the scaffold; agent makes their own two edits + commits."
