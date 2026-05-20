#!/usr/bin/env bash
# Shared helpers for jj-skill test scenarios.
#
# Source from a scenario's setup.sh or verify.sh:
#   source "$(dirname "$0")/../../lib/common.sh"

set -euo pipefail

# Default scenario name = parent directory of the calling script.
SCENARIO="${SCENARIO:-$(basename "$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)")}"
REPO_ROOT="${REPO_ROOT:-/tmp/jj-test/$SCENARIO}"

# Reset the scenario's repo to an empty colocated jj+git workspace.
init_repo() {
  rm -rf "$REPO_ROOT"
  mkdir -p "$REPO_ROOT"
  jj git init "$REPO_ROOT" >/dev/null 2>&1
  cd "$REPO_ROOT"
  # Override trunk() to mean the local `main` bookmark, so we don't need to
  # set up a real remote for tests to use `trunk()` revsets.
  jj config set --repo 'revset-aliases."trunk()"' 'main' >/dev/null
  # Allow scenarios to rewrite the trunk seed when staging starting state.
  # Production jj has main@origin etc. immutable; for tests, we relax.
  jj config set --repo 'revset-aliases."immutable_heads()"' 'none()' >/dev/null
  # Seed a base commit; git refs can't point at the root commit, so trunk
  # must live on a real commit.
  echo "# trunk seed" > .trunk-seed
  # Sidecars used by some scenarios (e.g. .change-ids, .A-change-id) must
  # NOT be snapshotted into commits; gitignore makes jj skip them.
  cat > .gitignore <<'EOF'
.change-ids
.A-change-id
EOF
  jj commit -m "init: trunk seed" >/dev/null 2>&1
  jj bookmark create main -r '@-' >/dev/null 2>&1
}

# Make a commit with the given description and optional files.
#   commit_with "msg" file1 file2 ...
# If no files given, commits the current working copy as-is.
commit_with() {
  local msg="$1"; shift
  if [ "$#" -gt 0 ]; then
    for f in "$@"; do
      [ -e "$f" ] || echo "$f content" > "$f"
    done
  fi
  jj commit -m "$msg" >/dev/null
}

# Print first-line description for a revision (default @).
desc() {
  local rev="${1:-@}"
  jj log -r "$rev" --no-graph --no-pager -T 'description.first_line()'
}

# Print the file list (with status) for a revision (default @).
files_at() {
  local rev="${1:-@}"
  jj show --summary --no-pager -r "$rev" | sed -n '/^[AMRD] /p'
}

# Count commits in trunk()..@ (exclusive of trunk).
stack_height() {
  jj log -r 'trunk()..@' --no-graph --no-pager -T '"x\n"' | wc -l | tr -d ' '
}

# ----- assertions ------------------------------------------------------------

fail() { echo "FAIL [$SCENARIO]: $*" >&2; exit 1; }
ok()   { echo "PASS [$SCENARIO]: $*"; }

assert_desc_matches() {
  local rev="$1" pattern="$2"
  local got; got=$(desc "$rev")
  if [[ ! "$got" =~ $pattern ]]; then
    fail "description of $rev: expected /$pattern/, got '$got'"
  fi
}

assert_desc_format() {
  # <prefix>/<sub>: <lowercase verb> ...
  local rev="${1:-@-}"
  local got; got=$(desc "$rev")
  if [[ ! "$got" =~ ^[a-z][a-zA-Z0-9_/-]+:[[:space:]][a-z]+[[:space:]] ]]; then
    fail "$rev description does not match '<prefix>: <verb> ...': got '$got'"
  fi
}

assert_stack_height() {
  local expected="$1"
  local got; got=$(stack_height)
  [ "$got" = "$expected" ] || fail "stack_height: expected $expected, got $got"
}

assert_file_at() {
  local rev="$1" path="$2"
  jj file show -r "$rev" "$path" >/dev/null 2>&1 || fail "$path missing at $rev"
}

assert_no_file_at() {
  local rev="$1" path="$2"
  if jj file show -r "$rev" "$path" >/dev/null 2>&1; then
    fail "$path should not be present at $rev"
  fi
}

assert_clean_working_copy() {
  local d; d=$(jj diff --summary --no-pager 2>&1)
  if [ -n "$d" ]; then
    fail "working copy not clean: $d"
  fi
}

assert_dirty_working_copy() {
  local d; d=$(jj diff --summary --no-pager 2>&1)
  if [ -z "$d" ]; then
    fail "working copy unexpectedly clean (setup didn't leave changes for the agent)"
  fi
}

# ----- starting-state helpers (call from setup.sh) ---------------------------

# Assert the starting state matches expectations. Call at end of setup.sh.
#   assert_starting_state <expected_stack_height> <expected_working_copy: clean|dirty>
# stack_height counts commits in trunk()..@ INCLUDING the empty @ if present.
assert_starting_state() {
  local expected_height="$1" wc_state="$2"
  local got_height; got_height=$(stack_height)
  if [ "$got_height" != "$expected_height" ]; then
    echo "SETUP ERROR [$SCENARIO]: stack_height expected=$expected_height got=$got_height" >&2
    jj log --no-pager -r '::@' >&2
    exit 2
  fi
  case "$wc_state" in
    clean) assert_clean_working_copy ;;
    dirty) assert_dirty_working_copy ;;
    *) echo "SETUP ERROR: assert_starting_state: bad wc_state '$wc_state' (clean|dirty)" >&2; exit 2 ;;
  esac
  echo "STARTING STATE OK [$SCENARIO]: height=$got_height, wc=$wc_state"
}
