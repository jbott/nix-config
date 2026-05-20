#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT"

assert_clean_working_copy
assert_stack_height 4

# Expected order bottom-up: A (ping), C (ratelimit), B (auth).
mapfile -t descs < <(jj log -r 'trunk()..@ ~ @' --no-pager --no-graph --reversed -T 'description.first_line() ++ "\n"')

[ "${#descs[@]}" = "3" ] || fail "expected 3 non-empty commits, got ${#descs[@]}: ${descs[*]}"

[[ "${descs[0]}" =~ ping ]]      || fail "expected A (ping) at bottom, got '${descs[0]}'"
[[ "${descs[1]}" =~ rate.limit ]] || fail "expected C (rate limit) in middle, got '${descs[1]}'"
[[ "${descs[2]}" =~ auth ]]      || fail "expected B (auth) on top, got '${descs[2]}'"

# All three files still present at the tip.
for f in services/api/ping.py services/api/auth.py services/api/ratelimit.py; do
  assert_file_at "@-" "$f"
done

# No conflicts.
conflicts=$(jj log -r 'conflicts()' --no-pager --no-graph -T '"x"' | wc -c)
[ "$conflicts" = "0" ] || fail "conflicts present after reorder"

ok "reorder-bc"
