#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT" || exit 1

assert_clean_working_copy
assert_desc_format "@-"
assert_desc_matches "@-" "^services/payments:"

# @- contains the validation work.
content=$(jj file show -r '@-' services/payments/handler.py)
echo "$content" | grep -q 'amount must be positive' || fail "@- missing validation work"

ok "editor-trap-recovery"
