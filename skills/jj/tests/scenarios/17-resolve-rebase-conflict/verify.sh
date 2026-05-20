#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT"

assert_clean_working_copy

# Stack tip is rebased onto the new trunk.
agent_tip=$(jj log -r 'description(glob:"*MAX_RETRIES to 10*")' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
[ -n "$agent_tip" ] || fail "agent's commit (MAX_RETRIES to 10) not found"
parent_desc=$(jj log -r "$agent_tip-" --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
[ "$parent_desc" = "docs/team: change MAX_RETRIES to 5" ] \
  || fail "agent's stack parent is '$parent_desc'; expected the new trunk commit"

# config.py has 10, not 5, not 3, not conflict markers.
content=$(jj file show -r "$agent_tip" src/config.py)
echo "$content" | grep -q 'MAX_RETRIES = 10' || fail "MAX_RETRIES = 10 missing at @-"
echo "$content" | grep -q 'MAX_RETRIES = 5'  && fail "MAX_RETRIES = 5 still present at @-"
echo "$content" | grep -qE '<<<<<<<|>>>>>>>|=======' && fail "conflict markers still in src/config.py"

# No conflicts in the repo.
conflicts=$(jj log -r 'conflicts()' --no-pager --no-graph -T '"x"' | wc -c)
[ "$conflicts" = "0" ] || fail "conflicts() revset non-empty"

ok "resolve-rebase-conflict"
