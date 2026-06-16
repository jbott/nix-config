#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"

init_repo

# Apply the local jj aliases the skill references.
jj config set --repo 'aliases.rom' \
  '["rebase", "--onto", "trunk()", "--skip-emptied", "--simplify-parents"]' >/dev/null

# Snapshot the trunk seed change-id.
old_trunk=$(jj log -r 'trunk()' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)

# Build the agent's stack on top of old trunk.
mkdir -p services/api
echo "def list_users(): return []" > services/api/users.py
commit_with "services/api: add /v1/users"
# Right after commit_with, @- holds the just-created commit.
agent_stack_tip=$(jj log -r '@-' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)

# Create the NEW trunk commit as a sibling of the agent's stack
# (child of old trunk, parallel to the agent's work).
jj new -r "$old_trunk" >/dev/null
echo "# Contributing" > CONTRIBUTING.md
jj describe -m "docs: add CONTRIBUTING" >/dev/null
new_trunk=$(jj log -r '@' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)

# Repoint main to the new trunk commit.
jj bookmark set main -r "$new_trunk" --allow-backwards >/dev/null

# Move @ to a fresh empty child of the agent's stack tip.
jj new -r "$agent_stack_tip" >/dev/null

# Sanity.
trunk_desc=$(jj log -r 'trunk()' --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
[ "$trunk_desc" = "docs: add CONTRIBUTING" ] || { echo "SETUP ERROR: trunk() not at CONTRIBUTING: '$trunk_desc'"; exit 2; }

stack_parent_desc=$(jj log -r "$agent_stack_tip-" --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
[ "$stack_parent_desc" = "init: trunk seed" ] || { echo "SETUP ERROR: agent's stack parent is '$stack_parent_desc', expected 'init: trunk seed'"; exit 2; }

assert_clean_working_copy
echo "Setup complete: $REPO_ROOT"
echo "Agent's stack: trunk seed -> /v1/users -> @ (empty). trunk() now points at CONTRIBUTING (sibling commit)."
