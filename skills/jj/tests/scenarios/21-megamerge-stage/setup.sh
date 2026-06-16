#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"

init_repo

# Branch A on trunk.
mkdir -p services/a
echo "def handle(): return 'a'" > services/a/handler.py
commit_with "services/a: add handler"
jj bookmark create john/feature-a -r '@-' >/dev/null

# Branch B on trunk (start a fresh @ off main).
jj new main >/dev/null
mkdir -p services/b
echo "def handle(): return 'b'" > services/b/handler.py
commit_with "services/b: add handler"
jj bookmark create john/feature-b -r '@-' >/dev/null

# Megamerge: explicitly merge feature-a and feature-b on top of trunk.
# `jj new` makes @ the merge; finalise it with `jj describe` so its
# description survives the subsequent `jj new` (otherwise the next commit
# would land inside the merge).
jj new -m "merge: integration" main john/feature-a john/feature-b >/dev/null
jj new >/dev/null   # fresh empty @ on top of the merge

# One non-empty commit on top of the megamerge — feature-c work.
mkdir -p services/c
echo "def handle(): return 'c'" > services/c/handler.py
commit_with "services/c: add handler"

# Verify the merge is reachable as closest_merge(@) before handing off.
merge_change=$(jj log -r 'closest_merge(@)' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)
if [ -z "$merge_change" ]; then
  echo "SETUP ERROR [$SCENARIO]: closest_merge(@) is empty; megamerge wasn't recognised" >&2
  jj log --no-pager -r '::@' >&2
  exit 2
fi

assert_clean_working_copy
echo "STARTING STATE OK [$SCENARIO]: megamerge with services/c on top"
echo "Setup complete: $REPO_ROOT"
