#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT"

assert_clean_working_copy

# closest_merge(@) must still resolve to a merge commit.
merge=$(jj log -r 'closest_merge(@)' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
[ -n "$merge" ] || fail "closest_merge(@) returned no commit — megamerge is missing"

# It must have at least 3 non-root parents (feature-a, feature-b, feature-c).
parent_count=$(jj log -r "$merge-" --no-graph --no-pager -T '"x\n"' | wc -l | tr -d ' ')
[ "$parent_count" -ge 3 ] || fail "megamerge has $parent_count parents, expected >= 3"

# One of those parents must contain services/c/handler.py.
mapfile -t parents < <(jj log -r "$merge-" --no-graph --no-pager -T 'change_id ++ "\n"')
found_c=0
for p in "${parents[@]}"; do
  if jj file show -r "$p" services/c/handler.py >/dev/null 2>&1; then
    found_c=1
    break
  fi
done
[ "$found_c" = "1" ] || fail "no merge parent contains services/c/handler.py"

# The slot immediately above the merge (descendants between merge and @,
# exclusive of @) must be empty.
mapfile -t above < <(jj log -r "${merge}+:: & ::@ ~ ${merge} ~ @" --no-pager --no-graph -T 'change_id ++ "\n"')
for c in "${above[@]}"; do
  files=$(jj show --summary --no-pager -r "$c" | sed -n '/^[AMRD] /p')
  [ -z "$files" ] || fail "commit $c above the merge is non-empty: $files"
done

ok "megamerge-stage"
