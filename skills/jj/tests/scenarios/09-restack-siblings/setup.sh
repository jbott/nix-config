#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"

init_repo

jj config set --repo 'aliases.restack' \
  '["rebase", "--onto", "trunk()", "--source", "mutable_roots() ~ ::(working_copies() ~ @)", "--skip-emptied", "--simplify-parents"]' >/dev/null
jj config set --repo 'revset-aliases."mutable_roots()"' 'roots(trunk()..) & mutable()' >/dev/null

old_trunk=$(jj log -r 'trunk()' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)

# Sibling stack 1: api-orders.
jj new -r "$old_trunk" >/dev/null
mkdir -p services/api
echo "def list_orders(): return []" > services/api/orders.py
jj describe -m "services/api: add /v1/orders" >/dev/null
orders_change=$(jj log -r '@' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
jj bookmark create john/api-orders -r "$orders_change" >/dev/null

# Current stack: api-users.
jj new -r "$old_trunk" >/dev/null
mkdir -p services/api
echo "def list_users(): return []" > services/api/users.py
jj describe -m "services/api: add /v1/users" >/dev/null
users_change=$(jj log -r '@' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
jj bookmark create john/api-users -r "$users_change" >/dev/null

# Advance trunk: new commit on top of old trunk.
jj new -r "$old_trunk" >/dev/null
echo "# Contributing" > CONTRIBUTING.md
jj describe -m "docs: add CONTRIBUTING" >/dev/null
new_trunk=$(jj log -r '@' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
jj bookmark set main -r "$new_trunk" --allow-backwards >/dev/null

# @ = empty child of api-users tip.
jj new -r "$users_change" >/dev/null

# Sanity.
for change in "$users_change" "$orders_change"; do
  parent_desc=$(jj log -r "${change}-" --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
  [ "$parent_desc" = "init: trunk seed" ] \
    || { echo "SETUP ERROR: commit $change parent is '$parent_desc', expected trunk seed"; exit 2; }
done

at_parent_desc=$(jj log -r '@-' --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
[ "$at_parent_desc" = "services/api: add /v1/users" ] \
  || { echo "SETUP ERROR: @ parent is '$at_parent_desc', expected api-users tip"; exit 2; }

assert_clean_working_copy
echo "Setup complete: $REPO_ROOT"
echo "Two divergent stacks (api-users, api-orders) rooted on old trunk. @ is on api-users tip."
