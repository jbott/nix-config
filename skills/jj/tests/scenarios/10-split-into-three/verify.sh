#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT"

assert_clean_working_copy
# 3 real commits + empty @ = stack height 4.
assert_stack_height 4

# Collect descriptions and files per commit.
mapfile -t commits < <(jj log -r 'trunk()..@ ~ empty()' --no-pager --no-graph -T 'change_id ++ "\n"')
[ "${#commits[@]}" = "3" ] || fail "expected 3 non-empty commits, got ${#commits[@]}"

found_x=0 found_y=0 found_refactor=0
for c in "${commits[@]}"; do
  files=$(jj show --summary --no-pager -r "$c" | sed -n '/^[AMD] /p' | awk '{print $2}')
  desc=$(jj log -r "$c" --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
  # Description must look like <prefix>: <verb> ...
  [[ "$desc" =~ ^[a-z][a-zA-Z0-9_/-]+:[[:space:]][a-z]+[[:space:]] ]] \
    || fail "commit '$desc' does not match prefix format"

  has_x=0 has_y=0 has_ref=0
  while IFS= read -r f; do
    case "$f" in
      services/x/*)        has_x=1 ;;
      services/y/*)        has_y=1 ;;
      lib/common/*)        has_ref=1 ;;
      *) ;;
    esac
  done <<< "$files"
  mixed=$((has_x + has_y + has_ref))
  [ "$mixed" -le 1 ] || fail "commit '$desc' mixes file groups (x=$has_x y=$has_y refactor=$has_ref)"
  [ "$has_x" = "1" ]   && found_x=1
  [ "$has_y" = "1" ]   && found_y=1
  [ "$has_ref" = "1" ] && found_refactor=1
done

[ "$found_x" = "1" ]        || fail "no commit contains feature X files"
[ "$found_y" = "1" ]        || fail "no commit contains bug Y files"
[ "$found_refactor" = "1" ] || fail "no commit contains refactor files"

ok "split-into-three"
