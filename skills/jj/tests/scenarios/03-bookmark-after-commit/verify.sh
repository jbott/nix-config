#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT"

# Find any john/ bookmark.
name=$(jj bookmark list --no-pager -T 'name ++ "\n"' | grep '^john/' | head -n1)
[ -n "$name" ] || fail "no john/ bookmark found"

# Kebab-case (lowercase, hyphens), 2-4 segments after the slash.
suffix="${name#john/}"
[[ "$suffix" =~ ^[a-z][a-z0-9-]*$ ]] || fail "bookmark suffix not kebab-case: '$suffix'"

# Bookmark must point at a non-empty commit (i.e. not at @).
target_change=$(jj log -r "$name" --no-pager --no-graph -T 'change_id ++ "\n"' | head -n1)
at_change=$(jj log -r '@' --no-pager --no-graph -T 'change_id ++ "\n"' | head -n1)
[ "$target_change" != "$at_change" ] || fail "$name points at @ (empty working copy); should point at @-"

# The target must be empty()=false (real commit, not empty).
is_empty=$(jj log -r "$name" --no-pager --no-graph -T 'if(empty, "true", "false")')
[ "$is_empty" = "false" ] || fail "$name points at an empty commit"

ok "bookmark-after-commit ($name)"
