#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT" || exit 1

assert_clean_working_copy

# @- should be the new commit with project-prefix format.
assert_desc_format "@-"
assert_desc_matches "@-" "^services/api:"

# Both files modified at @-.
jj show --summary --no-pager -r '@-' | grep -q "services/api/handler.py" \
  || fail "handler.py not in @-"
jj show --summary --no-pager -r '@-' | grep -q "services/api/README.md" \
  || fail "README.md not in @-"

ok "commit-with-format"
