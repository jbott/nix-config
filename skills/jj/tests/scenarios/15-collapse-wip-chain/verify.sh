#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT" || exit 1

assert_clean_working_copy
# A + single + @ = 3.
assert_stack_height 3

source .change-ids   # exposes $A, $wip1, $wip2, $wip3

# A still exists at the same change-id with its original description.
A_desc=$(jj log -r "$A" --no-graph --no-pager -T 'description.first_line() ++ "\n"' 2>/dev/null | head -n1)
[ "$A_desc" = "services/cron: add scheduler skeleton" ] \
  || fail "A changed (or was consumed). Current desc: '$A_desc'"

# Exactly one non-empty commit between A and @.
mapfile -t between < <(jj log -r "($A..@) ~ empty()" --no-pager --no-graph -T 'change_id ++ "\n"')
[ "${#between[@]}" = "1" ] || fail "expected 1 commit between A and @, got ${#between[@]}: ${between[*]}"

# That single commit must have a project-prefix description and contain
# all of register_job, tick, stop (from the three wips combined).
single_change="${between[0]}"
single_desc=$(jj log -r "$single_change" --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
[[ "$single_desc" =~ ^[a-z][a-zA-Z0-9_/-]+:[[:space:]][a-z]+[[:space:]] ]] \
  || fail "collapsed commit description does not match prefix format: '$single_desc'"

content=$(jj file show -r "$single_change" services/cron/scheduler.py)
echo "$content" | grep -q 'register_job' || fail "collapsed commit missing register_job"
echo "$content" | grep -q 'def tick'      || fail "collapsed commit missing tick"
echo "$content" | grep -q 'def stop'      || fail "collapsed commit missing stop"

ok "collapse-wip-chain"
