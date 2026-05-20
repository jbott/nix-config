#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT"

assert_clean_working_copy

# Find the agent's stack tip (the /v1/users commit).
stack_change=$(jj log -r 'description(glob:"services/api: add /v1/users*")' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
[ -n "$stack_change" ] || fail "users commit not found"

# Its parent must be the CONTRIBUTING commit (the new trunk tip).
parent_desc=$(jj log -r "$stack_change-" --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
[ "$parent_desc" = "docs: add CONTRIBUTING" ] \
  || fail "agent's stack parent is '$parent_desc'; expected 'docs: add CONTRIBUTING'"

# trunk() must point at the CONTRIBUTING commit too.
trunk_desc=$(jj log -r 'trunk()' --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
[ "$trunk_desc" = "docs: add CONTRIBUTING" ] || fail "trunk() not at CONTRIBUTING: '$trunk_desc'"

# users.py still exists at @-.
assert_file_at "@-" "services/api/users.py"

ok "rom-alias"
