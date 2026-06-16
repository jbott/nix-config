#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT" || exit 1

assert_clean_working_copy
# 1 real commit + empty @ = stack height 2.
assert_stack_height 2

# @- must contain both the original function AND the try/except addition.
content=$(jj file show -r '@-' services/api/health.py)
echo "$content" | grep -q 'def health' || fail "@- missing def health"
echo "$content" | grep -q 'try:'       || fail "@- missing try/except (the second change wasn't squashed in)"
echo "$content" | grep -q 'degraded'   || fail "@- missing 'degraded' string from the second change"

# Description must follow prefix format.
assert_desc_format "@-"

ok "squash-into-parent"
