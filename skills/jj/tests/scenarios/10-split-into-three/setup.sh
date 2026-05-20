#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"

init_repo

mkdir -p services/x services/y lib/common
cat > services/x/handler.py <<'EOF'
def handle(req): return {"feature": "x"}
EOF
cat > services/x/router.py <<'EOF'
def route(path): return path
EOF
cat > services/y/validator.py <<'EOF'
def validate(req): return req is not None
EOF
cat > services/y/tests.py <<'EOF'
def test_validate(): assert True
EOF
cat > lib/common/helpers.py <<'EOF'
def first(seq): return next(iter(seq), None)
EOF

commit_with "wip: dump of changes"

# Stack height: 1 (the dump) + empty @ = 2.
assert_starting_state 2 clean

echo "Setup complete: $REPO_ROOT"
echo "Single 'wip' commit at @- touches 5 files in 3 logical groups."
