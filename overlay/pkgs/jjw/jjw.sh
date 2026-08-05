#!/usr/bin/env bash
# jjw — jj workspace helper.
#
# Owns a single path convention for secondary workspaces:
#
#     <parent-of-main-repo>/.worktrees/<main-repo>/<name>
#
# so the Claude Code worktree hooks, the `jj w` alias, and interactive use all
# agree on where the workspace named <name> lives. Keeping worktrees beside the
# repo (not under it) avoids nesting them inside the tracked tree; the
# <main-repo> segment namespaces them so sibling repos sharing a parent don't
# collide on a common worktree name.

set -eu -o pipefail

prog=jjw

die() {
  printf '%s: %s\n' "$prog" "$*" >&2
  exit 1
}
note() { printf '%s: %s\n' "$prog" "$*" >&2; }

usage() {
  cat <<EOF
usage: $prog [-R <repo>] <command> [args]

commands:
  new|add [-r <revset>] <name>
        Create the workspace for <name> and print its path. Reuses an existing
        one, so it doubles as "resolve or create". Creates no bookmark: name a
        branch with 'jj bookmark create' once there is something to push.
  rm [--stale] <name>...
        Forget each workspace and delete its directory. Refuses the workspace
        you are standing in and the main workspace.
        --stale forgets every tracked workspace whose directory is gone from
        disk (and takes no names).
  ls [--stale]
        List existing workspaces as <name><TAB><path>. --stale lists only those
        whose directory is gone from disk.
  root [<name>]
        Print the root of <name>, or of the main workspace if omitted.
EOF
}

repo_flag=()

# Read-only jj query. --ignore-working-copy keeps a mere lookup from
# snapshotting (and thus mutating) whichever working copy we happen to be in.
jjq() { jj "${repo_flag[@]}" --ignore-working-copy "$@"; }

# Absolute path of the MAIN workspace root.
#
# We resolve the main root rather than trusting the cwd or -R target, which may
# itself be a secondary workspace (e.g. Claude launched inside a worktree) —
# using it directly would nest worktrees inside worktrees. jj's `$root/.jj/repo`
# is a directory in the main workspace but a file holding a path to
# <main>/.jj/repo in secondary workspaces, so we follow it to recover the main
# root. Source: https://github.com/kawaz/jj-worktree/issues/1
repo_root() {
  local ws_root main_jj
  ws_root=$(jjq workspace root) || die "not in a jj repo"
  if [ -f "$ws_root/.jj/repo" ]; then
    main_jj=$(cd "$ws_root/.jj" && cd "$(dirname "$(cat repo)")" && pwd)
    dirname "$main_jj"
  else
    printf '%s\n' "$ws_root"
  fi
}

ws_path() {
  local root=$1 name=$2
  printf '%s/.worktrees/%s/%s\n' "$(dirname "$root")" "$(basename "$root")" "$name"
}

ws_exists() {
  jjq workspace list -T 'name ++ "\n"' | grep -Fxq "$1"
}

# Directory where workspace <name>'s files live: its jj-recorded path (jj
# >=0.38), or the convention path we would have created it at (older repos
# record no path).
ws_dir() {
  local root=$1 name=$2
  jjq workspace root --name "$name" 2>/dev/null || ws_path "$root" "$name"
}

# A workspace is stale when it is tracked but its directory is gone from disk.
# The main and current workspaces are never stale (their directories exist), so
# this never flags a workspace that is unsafe to forget.
ws_stale() {
  [ ! -d "$(ws_dir "$1" "$2")" ]
}

cmd_new() {
  local revset="" name=""
  while [ $# -gt 0 ]; do
    case $1 in
      -r | --revision)
        [ $# -ge 2 ] || die "new: missing argument to $1"
        revset=$2
        shift 2
        ;;
      -*) die "new: unknown option: $1" ;;
      *)
        [ -z "$name" ] || die "new: unexpected argument: $1"
        name=$1
        shift
        ;;
    esac
  done
  [ -n "$name" ] || die "new: missing <name>"

  local root path
  root=$(repo_root)
  path=$(ws_path "$root" "$name")

  if ws_exists "$name"; then
    [ -d "$path" ] ||
      die "workspace '$name' is tracked but $path is missing; run '$prog rm $name' to drop the stale entry, then retry"
    note "reusing workspace '$name' at $path"
    printf '%s\n' "$path"
    return 0
  fi

  local add=(workspace add --name "$name")
  [ -z "$revset" ] || add+=(--revision "$revset")
  mkdir -p "$(dirname "$path")"
  jj -R "$root" "${add[@]}" "$path" >&2
  printf '%s\n' "$path"
}

cmd_rm() {
  local stale_only=false name path
  local names=()
  while [ $# -gt 0 ]; do
    case $1 in
      --stale)
        stale_only=true
        shift
        ;;
      -*) die "rm: unknown option: $1" ;;
      *)
        names+=("$1")
        shift
        ;;
    esac
  done

  local root current
  root=$(repo_root)
  current=$(jjq workspace root)

  if $stale_only; then
    [ ${#names[@]} -eq 0 ] || die "rm: --stale removes every stale workspace and takes no names"
    local found=false
    while IFS= read -r name; do
      ws_stale "$root" "$name" || continue
      jj -R "$root" workspace forget "$name"
      note "forgot stale workspace '$name' (no directory on disk)"
      found=true
    done < <(jjq workspace list -T 'name ++ "\n"')
    $found || note "no stale workspaces"
    return 0
  fi

  [ ${#names[@]} -gt 0 ] || die "rm: missing <workspace>..."

  for name in "${names[@]}"; do
    ws_exists "$name" || die "rm: no such workspace: $name"

    # The recorded path is authoritative, but it only exists for workspaces in
    # repos initialized with jj >=0.38. Older ones report "no recorded path",
    # and we will not `rm -rf` a directory we cannot confirm jj owns.
    if ! path=$(jjq workspace root --name "$name" 2>/dev/null); then
      path=$(ws_path "$root" "$name")
      if [ -e "$path" ]; then
        die "rm: workspace '$name' has no recorded path (repo predates jj 0.38); delete its directory by hand, then run 'jj workspace forget $name'"
      fi
      # Nothing on disk to protect: this is a stale entry, so just forget it.
      jj -R "$root" workspace forget "$name"
      note "forgot stale workspace '$name' (no directory on disk)"
      continue
    fi

    [ "$path" != "$current" ] || die "rm: refusing to remove the workspace you are in: $name"
    [ "$path" != "$root" ] || die "rm: refusing to remove the main workspace: $name"

    jj -R "$root" workspace forget "$name"
    rm -rf "$path"
    note "removed workspace '$name' ($path)"
  done
}

cmd_ls() {
  local stale_only=false
  while [ $# -gt 0 ]; do
    case $1 in
      --stale)
        stale_only=true
        shift
        ;;
      -*) die "ls: unknown option: $1" ;;
      *) die "ls: unexpected argument: $1" ;;
    esac
  done

  local root name path
  root=$(repo_root)
  while IFS= read -r name; do
    ! $stale_only || ws_stale "$root" "$name" || continue
    # A "-" means jj has no recorded path for the workspace (see cmd_rm).
    path=$(jjq workspace root --name "$name" 2>/dev/null) || path=-
    printf '%s\t%s\n' "$name" "$path"
  done < <(jjq workspace list -T 'name ++ "\n"')
}

cmd_root() {
  [ $# -le 1 ] || die "root: expected at most one <name>"
  [ $# -eq 1 ] || {
    repo_root
    return 0
  }
  ws_exists "$1" || die "root: no such workspace: $1"
  jjq workspace root --name "$1" 2>/dev/null ||
    die "root: workspace '$1' has no recorded path (repo predates jj 0.38)"
}

while [ $# -gt 0 ]; do
  case $1 in
    -R | --repository)
      [ $# -ge 2 ] || die "missing argument to $1"
      repo_flag=(-R "$2")
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*) die "unknown option: $1" ;;
    *) break ;;
  esac
done

[ $# -gt 0 ] || {
  usage >&2
  exit 2
}
cmd=$1
shift

case $cmd in
  # `add` spells the same thing as `jj workspace add` and `git worktree add`.
  new | add) cmd_new "$@" ;;
  rm) cmd_rm "$@" ;;
  ls) cmd_ls "$@" ;;
  root) cmd_root "$@" ;;
  *)
    usage >&2
    die "unknown command: $cmd"
    ;;
esac
