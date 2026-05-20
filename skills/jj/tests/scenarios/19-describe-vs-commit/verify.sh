#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT"

# The whole point: @ must be empty after. If agent used `jj describe -m`,
# @ would still have the type-validation changes.
assert_clean_working_copy

# @- has the work with a prefix-format description.
assert_desc_format "@-"
assert_desc_matches "@-" "^services/inventory:"

# @- contains the new type validation.
content=$(jj file show -r '@-' services/inventory/handler.py)
echo "$content" | grep -q 'TypeError' || fail "@- missing type-validation work"

ok "describe-vs-commit"
