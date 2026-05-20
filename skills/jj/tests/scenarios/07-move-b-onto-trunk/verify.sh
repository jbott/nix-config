#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT"

assert_clean_working_copy

# B should now be a child of trunk(): exists in repo, parent = trunk().
b_change=$(jj log -r 'description(glob:"*typo in README*")' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
[ -n "$b_change" ] || fail "B (typo commit) not found in repo"
b_parent_desc=$(jj log -r "$b_change-" --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
[ "$b_parent_desc" = "init: trunk seed and README" ] \
  || fail "B's parent is '$b_parent_desc', expected the trunk seed"

# Current stack (trunk()..@) should contain only A and C now, in that order.
mapfile -t stack_descs < <(jj log -r 'trunk()..@ ~ @' --no-pager --no-graph --reversed -T 'description.first_line() ++ "\n"')
[ "${#stack_descs[@]}" = "2" ] || fail "expected 2 commits in main stack (A, C), got ${#stack_descs[@]}: ${stack_descs[*]}"
[[ "${stack_descs[0]}" =~ scaffold ]] || fail "expected A (scaffold) at bottom, got '${stack_descs[0]}'"
[[ "${stack_descs[1]}" =~ health ]]   || fail "expected C (health) on top, got '${stack_descs[1]}'"

# README must NOT be modified in the A/C stack (the fix lives only on B's branch).
jj diff --git --no-pager -r '@-' README.md 2>/dev/null | grep -q 'README.md' \
  && fail "README.md still modified in @- (C); should be untouched by the A/C stack"

ok "move-b-onto-trunk"
