#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT" || exit 1

assert_clean_working_copy
# 2 real commits + empty @ = stack height 3.
assert_stack_height 3

# Both real commits in the stack have prefix format.
mapfile -t descs < <(jj log -r 'trunk()..@ ~ empty()' --no-pager --no-graph --reversed -T 'description.first_line() ++ "\n"')
[ "${#descs[@]}" = "2" ] || fail "expected 2 commits in stack, got ${#descs[@]}: ${descs[*]}"
for d in "${descs[@]}"; do
  [[ "$d" =~ ^[a-z][a-zA-Z0-9_/-]+:[[:space:]][a-z]+[[:space:]] ]] \
    || fail "description '$d' does not match '<prefix>: <verb> ...'"
done

# One commit touches services/api, one touches lib/utils.
api_hits=0
util_hits=0
mapfile -t changes < <(jj log -r 'trunk()..@ ~ empty()' --no-pager --no-graph -T 'change_id ++ "\n"')
for c in "${changes[@]}"; do
  files=$(jj show --summary --no-pager -r "$c" | sed -n '/^[AMRD] /p' | awk '{print $2}')
  echo "$files" | grep -q '^services/api/' && api_hits=$((api_hits + 1))
  echo "$files" | grep -q '^lib/utils/'    && util_hits=$((util_hits + 1))
done
[ "$api_hits" -ge 1 ]  || fail "no commit touches services/api/"
[ "$util_hits" -ge 1 ] || fail "no commit touches lib/utils/"

ok "stack-two-commits"
