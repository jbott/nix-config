#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"

init_repo

mkdir -p services/api
cat > services/api/health.py <<'EOF'
def health():
    return "ok"
EOF
commit_with "services/api: add health check"

# Now modify the file at @ (uncommitted changes).
cat > services/api/health.py <<'EOF'
def health():
    try:
        return "ok"
    except Exception as e:
        return f"degraded: {e}"
EOF

# Starting state: 1 prior commit + dirty @ = stack height 2, wc dirty.
assert_starting_state 2 dirty

echo "Setup complete: $REPO_ROOT"
echo "@ has uncommitted changes to services/api/health.py (adds try/except)."
