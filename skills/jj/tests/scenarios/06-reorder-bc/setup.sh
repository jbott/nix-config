#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"

init_repo

mkdir -p services/api
echo "def ping(): return 'pong'" > services/api/ping.py
commit_with "services/api: add ping endpoint"
echo "def auth(req): return req.get('user')" > services/api/auth.py
commit_with "services/api: add auth middleware"
echo "def rate_limit(req): return True" > services/api/ratelimit.py
commit_with "services/api: add rate limit"

# Stack height: trunk seed + A + B + C + empty @ = 4.
assert_starting_state 4 clean

echo "Setup complete: $REPO_ROOT"
echo "Stack: trunk -> A (ping) -> B (auth) -> C (ratelimit) -> @"
