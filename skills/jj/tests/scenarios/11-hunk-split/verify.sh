#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT" || exit 1

assert_clean_working_copy
# 2 real commits (the two splits) + empty @ = stack height 3.
# (The "scaffold" commit is part of the original trunk()..@ stack too,
# so total height would include it. Let's count what's in trunk()..@.)
# Expected stack: scaffold, bugfix, cleanup, @ → height 4. Or if the agent
# squashed scaffold (shouldn't), less. Allow >= 4.
got_h=$(stack_height)
[ "$got_h" = "4" ] || fail "expected stack_height 4 (scaffold + bugfix + cleanup + @), got $got_h"

# Inspect the two non-scaffold commits in trunk()..@.
mapfile -t commits < <(jj log -r 'trunk()..@ ~ empty() ~ description(glob:"*scaffold*")' --no-pager --no-graph -T 'change_id ++ "\n"')
[ "${#commits[@]}" = "2" ] || fail "expected 2 non-scaffold commits, got ${#commits[@]}"

found_bugfix=0
found_cleanup=0
for c in "${commits[@]}"; do
  diff=$(jj diff --git --no-pager -r "$c")
  desc=$(jj log -r "$c" --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
  [[ "$desc" =~ ^[a-z][a-zA-Z0-9_/-]+:[[:space:]][a-z]+[[:space:]] ]] \
    || fail "commit '$desc' does not match prefix format"

  has_bugfix=0; has_cleanup=0
  echo "$diff" | grep -q 'import time'    && has_bugfix=1
  echo "$diff" | grep -q 'cur \*= 2'      && has_bugfix=1
  echo "$diff" | grep -q 'cur = delay'    && has_bugfix=1
  echo "$diff" | grep -q 'dict(status='   && has_cleanup=1
  echo "$diff" | grep -q '# cleanup'      && has_cleanup=1

  mixed=$((has_bugfix + has_cleanup))
  [ "$mixed" -le 1 ] || fail "commit '$desc' contains both bugfix and cleanup hunks"
  [ "$has_bugfix" = "1" ]  && found_bugfix=1
  [ "$has_cleanup" = "1" ] && found_cleanup=1
done

[ "$found_bugfix" = "1" ]  || fail "no commit contains the backoff bugfix"
[ "$found_cleanup" = "1" ] || fail "no commit contains the format_response cleanup"

ok "hunk-split"
