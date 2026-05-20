#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT"

assert_clean_working_copy
assert_stack_height 4

# Find each ancestor commit by description and verify it contains the fixup.
A=$(jj log -r 'description(glob:"*/v1/users*")' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
B=$(jj log -r 'description(glob:"*/v1/orders*")' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
C=$(jj log -r 'description(glob:"*/v1/products*")' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
[ -n "$A" ] && [ -n "$B" ] && [ -n "$C" ] || fail "could not find A, B, or C commits"

for rev in "$A" "$B" "$C"; do
  desc=$(jj log -r "$rev" --no-graph --no-pager -T 'description.first_line() ++ "\n"' | head -n1)
  case "$desc" in
    *users*)    path=services/api/users.py ;;
    *orders*)   path=services/api/orders.py ;;
    *products*) path=services/api/products.py ;;
    *)          fail "unexpected commit '$desc'" ;;
  esac
  content=$(jj file show -r "$rev" "$path")
  echo "$content" | grep -q 'canonical empty list' \
    || fail "fixup not absorbed into $desc — $path missing 'canonical empty list'"
done

ok "absorb-fixups"
