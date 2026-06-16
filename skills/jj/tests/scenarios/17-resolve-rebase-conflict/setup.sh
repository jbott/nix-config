#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"

init_repo

# Add src/config.py to the trunk seed (via amending @-, the trunk seed).
mkdir -p src
cat > src/config.py <<'EOF'
"""App config."""

MAX_RETRIES = 3
TIMEOUT_S = 30
EOF
# Roll into trunk seed by squashing @ -> @- (the trunk seed).
jj squash --into '@-' -m "init: trunk seed" >/dev/null

old_trunk=$(jj log -r 'trunk()' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)

# Agent's stack: change MAX_RETRIES to 10.
sed -i 's/MAX_RETRIES = 3/MAX_RETRIES = 10/' src/config.py
commit_with "src/config: bump MAX_RETRIES to 10"
agent_stack_tip=$(jj log -r '@-' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)

# New trunk commit (a sibling): change MAX_RETRIES to 5.
jj new -r "$old_trunk" >/dev/null
sed -i 's/MAX_RETRIES = 3/MAX_RETRIES = 5/' src/config.py
jj describe -m "docs/team: change MAX_RETRIES to 5" >/dev/null
new_trunk=$(jj log -r '@' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
jj bookmark set main -r "$new_trunk" --allow-backwards >/dev/null

# @ back to the agent's stack tip as an empty child.
jj new -r "$agent_stack_tip" >/dev/null

assert_clean_working_copy
echo "Setup complete: $REPO_ROOT"
echo "Stack: old_trunk -> (agent's commit: MAX_RETRIES = 10) -> @ (empty)"
echo "Sibling new trunk: (docs/team: MAX_RETRIES = 5). trunk() points at the new trunk."
