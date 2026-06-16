#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"

init_repo

mkdir -p services/api
cat > services/api/handler.py <<'EOF'
def handle(req):
    return {"status": "ok"}
EOF
cat > services/api/README.md <<'EOF'
# API service
EOF
commit_with "services/api: scaffold handler"

# Now modify the files so @ has uncommitted changes for the agent to commit.
cat > services/api/handler.py <<'EOF'
def handle(req):
    if not req.get("user"):
        return {"status": "error", "reason": "missing user"}
    return {"status": "ok", "user": req["user"]}
EOF
cat >> services/api/README.md <<'EOF'

## Authentication
Requests must include a `user` field.
EOF

# Starting state: 1 prior commit in trunk()..@ (the scaffold), @ has changes.
# Stack height counts the empty @ + the scaffold commit = 2.
assert_starting_state 2 dirty
echo "Setup complete: $REPO_ROOT"
echo "Working copy has uncommitted changes to services/api/{handler.py,README.md}"
