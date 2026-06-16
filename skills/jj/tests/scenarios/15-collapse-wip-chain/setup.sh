#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"

init_repo

mkdir -p services/cron

# A: real commit, pre-WIP.
cat > services/cron/scheduler.py <<'EOF'
class Scheduler:
    def __init__(self):
        self.jobs = []
EOF
commit_with "services/cron: add scheduler skeleton"
A_change=$(jj log -r '@-' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)

# wip1: add register_job
cat >> services/cron/scheduler.py <<'EOF'

    def register_job(self, fn, when):
        self.jobs.append((when, fn))
EOF
commit_with "wip: register_job"
wip1_change=$(jj log -r '@-' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)

# wip2: add tick.
cat >> services/cron/scheduler.py <<'EOF'

    def tick(self, now):
        for when, fn in list(self.jobs):
            if when <= now:
                fn()
EOF
commit_with "wip: tick"
wip2_change=$(jj log -r '@-' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)

# wip3: add stop.
cat >> services/cron/scheduler.py <<'EOF'

    def stop(self):
        self.jobs.clear()
EOF
commit_with "wip: stop"
wip3_change=$(jj log -r '@-' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)

# Persist the change-ids so verify and agent can use them.
{
  echo "A=$A_change"
  echo "wip1=$wip1_change"
  echo "wip2=$wip2_change"
  echo "wip3=$wip3_change"
} > .change-ids

# Stack height: trunk()..@ = A + wip1 + wip2 + wip3 + @ = 5.
assert_starting_state 5 clean

echo "Setup complete: $REPO_ROOT"
echo "Stack: A (skeleton) -> wip1 (register_job) -> wip2 (tick) -> wip3 (stop) -> @ (empty)"
echo "Change-ids written to .change-ids"
