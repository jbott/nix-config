#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT"

assert_clean_working_copy

# Find the two non-empty commits in trunk()..@.
mapfile -t commits < <(jj log -r 'trunk()..@ ~ empty()' --no-pager --no-graph -T 'change_id ++ "\n"')
[ "${#commits[@]}" = "2" ] || fail "expected 2 non-empty commits, got ${#commits[@]}"

# Both must have project-prefix descriptions.
for c in "${commits[@]}"; do
  desc=$(jj log -r "$c" --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
  [[ "$desc" =~ ^[a-z][a-zA-Z0-9_/-]+:[[:space:]][a-z]+[[:space:]] ]] \
    || fail "commit '$desc' does not match prefix format"
done

# Each must contain exactly one of the two services.
found_foo=0
found_bar=0
for c in "${commits[@]}"; do
  files=$(jj show --summary --no-pager -r "$c" | sed -n '/^[AMD] /p' | awk '{print $2}')
  has_foo=0; has_bar=0
  while IFS= read -r f; do
    case "$f" in
      services/foo/*) has_foo=1 ;;
      services/bar/*) has_bar=1 ;;
    esac
  done <<< "$files"
  mixed=$((has_foo + has_bar))
  [ "$mixed" = "1" ] || fail "commit contains both or neither service (foo=$has_foo bar=$has_bar)"
  [ "$has_foo" = "1" ] && found_foo=1
  [ "$has_bar" = "1" ] && found_bar=1
done
[ "$found_foo" = "1" ] || fail "no foo commit"
[ "$found_bar" = "1" ] || fail "no bar commit"

# Both commits must have the SAME parent (parallel siblings).
parent_a=$(jj log -r "${commits[0]}-" --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
parent_b=$(jj log -r "${commits[1]}-" --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
[ "$parent_a" = "$parent_b" ] \
  || fail "commits are not siblings (parents differ: $parent_a vs $parent_b)"

ok "parallel-split"
