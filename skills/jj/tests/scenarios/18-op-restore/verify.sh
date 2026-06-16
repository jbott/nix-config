#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT" || exit 1

assert_clean_working_copy
assert_stack_height 4

# Stack descriptions bottom-up should be A, B, C.
mapfile -t descs < <(jj log -r 'trunk()..@ ~ empty()' --no-pager --no-graph --reversed -T 'description.first_line() ++ "\n"')
[ "${#descs[@]}" = "3" ] || fail "expected 3 non-empty commits, got ${#descs[@]}: ${descs[*]}"
[[ "${descs[0]}" =~ add\ a ]] || fail "expected A (add a) at bottom, got '${descs[0]}'"
[[ "${descs[1]}" =~ add\ b ]] || fail "expected B (add b) in middle, got '${descs[1]}'"
[[ "${descs[2]}" =~ add\ c ]] || fail "expected C (add c) on top, got '${descs[2]}'"

# All three files present at @-.
for f in src/a.py src/b.py src/c.py; do
  assert_file_at "@-" "$f"
done

ok "op-restore"
