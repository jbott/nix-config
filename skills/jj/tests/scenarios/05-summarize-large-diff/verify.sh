#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"
cd "$REPO_ROOT" || exit 1

# Soft check: the agent should NOT have rewritten the commit. Stack height
# unchanged and the big commit still has its description.
assert_clean_working_copy
assert_stack_height 2
assert_desc_matches "@-" "services: scaffold four service handlers"

# We can't verify the agent's prose summary here — that's a manual review.
# This verifier just confirms the agent didn't accidentally mutate the repo.
ok "summarize-large-diff (repo unmutated; review agent's summary manually)"
