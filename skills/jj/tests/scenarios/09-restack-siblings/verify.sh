#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT"

# api-orders bookmark must have the new trunk tip as an ancestor.
orders_change=$(jj log -r 'john/api-orders' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
[ -n "$orders_change" ] || fail "john/api-orders bookmark missing"
parent_desc=$(jj log -r "$orders_change-" --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
[ "$parent_desc" = "docs: add CONTRIBUTING" ] \
  || fail "api-orders parent is '$parent_desc', expected 'docs: add CONTRIBUTING'"

# api-users bookmark should ALSO now have CONTRIBUTING as parent — `jj restack`
# in single-workspace mode rebases every local mutable stack, including the
# one `@` is on. (Only stacks anchored by OTHER active workspaces are spared.)
users_change=$(jj log -r 'john/api-users' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
users_parent_desc=$(jj log -r "$users_change-" --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
[ "$users_parent_desc" = "docs: add CONTRIBUTING" ] \
  || fail "api-users parent is '$users_parent_desc', expected 'docs: add CONTRIBUTING'"

# @ should still be on the api-users line (its ancestor includes api-users tip).
at_ancestor_count=$(jj log -r "john/api-users::@" --no-pager --no-graph -T '"x\n"' | wc -l | tr -d ' ')
[ "$at_ancestor_count" -ge 1 ] || fail "@ is not on the api-users stack anymore"

ok "restack-siblings"
