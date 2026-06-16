#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT" || exit 1

assert_clean_working_copy
# A + B + C + @ still = 4.
assert_stack_height 4

A_change=$(cat .A-change-id)
# A still exists at the same change-id.
A_desc=$(jj log -r "$A_change" --no-graph --no-pager -T 'description.first_line() ++ "\n"' 2>/dev/null | head -n1)
[ -n "$A_desc" ] || fail "A's change-id $A_change no longer resolves"
[[ "$A_desc" =~ /users ]] || fail "A's description changed unexpectedly: '$A_desc'"

# A's content has the fixed function.
content=$(jj file show -r "$A_change" services/api/users.py)
echo "$content" | grep -q 'def list_users' || fail "A still has the typo (no 'def list_users')"
echo "$content" | grep -q 'def liste_users' && fail "A still contains 'def liste_users' (typo not fixed)"

# B and C are unchanged in the stack.
descs=$(jj log -r 'trunk()..@ ~ empty()' --no-pager --no-graph -T 'description.first_line() ++ "\n"')
echo "$descs" | grep -q '/users endpoint'    || fail "A's description missing from stack"
echo "$descs" | grep -q '/orders endpoint'   || fail "B's description missing from stack"
echo "$descs" | grep -q '/products endpoint' || fail "C's description missing from stack"

ok "squash-fixup-ancestor"
