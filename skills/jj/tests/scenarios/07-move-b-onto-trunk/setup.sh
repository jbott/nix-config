#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"

init_repo

# Put README on trunk (so B's typo-fix can rebase onto trunk cleanly,
# without depending on A creating the file).
cat > README.md <<'EOF'
# Test repo

This is a test repo for jj skil testing.
EOF
commit_with "init: trunk seed and README"
jj bookmark set main -r '@-' >/dev/null

# A: scaffold the API.
mkdir -p services/api
echo "def handle(req): return {'ok': True}" > services/api/handler.py
commit_with "services/api: scaffold service"

# B: typo fix in README.
sed -i 's/skil testing/skill testing/' README.md
commit_with "docs: fix typo in README"

# C: health check.
echo "def health(): return 'ok'" > services/api/health.py
commit_with "services/api: add health check"

# Stack height (trunk()..@, excluding trunk): A + B + C + @ = 4.
assert_starting_state 4 clean

echo "Setup complete: $REPO_ROOT"
echo "Stack: trunk -> A (scaffold + README) -> B (docs typo) -> C (health) -> @"
