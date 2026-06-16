#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"

init_repo

mkdir -p services/foo services/bar
cat > services/foo/handler.py <<'EOF'
def foo(req): return {"foo": True}
EOF
cat > services/bar/handler.py <<'EOF'
def bar(req): return {"bar": True}
EOF
commit_with "wip: independent additions"

assert_starting_state 2 clean
echo "Setup complete: $REPO_ROOT"
echo "Single 'wip' commit at @- has two independent files: services/foo and services/bar."
