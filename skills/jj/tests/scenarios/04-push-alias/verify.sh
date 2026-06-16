#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT" || exit 1

REMOTE_PATH="$(dirname "$REPO_ROOT")/04-push-alias-remote.git"

# Local bookmark target.
local_target=$(jj log -r 'john/add-email-notifier' --no-graph --no-pager -T 'commit_id ++ "\n"' | head -n1)
[ -n "$local_target" ] || fail "local bookmark john/add-email-notifier missing"

# Remote bookmark target.
remote_ref=$(git --git-dir="$REMOTE_PATH" show-ref refs/heads/john/add-email-notifier 2>/dev/null | awk '{print $1}')
[ -n "$remote_ref" ] || fail "bookmark john/add-email-notifier not present on origin"

[ "$local_target" = "$remote_ref" ] \
  || fail "remote bookmark points at $remote_ref, local at $local_target"

ok "push-alias"
