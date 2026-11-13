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
        one, so it doubles as "resolve or create". Defaults to the local bookmark
        matching <name>, if it exists; -r overrides this. Creates no bookmark: name a
        branch with 'jj bookmark create' once there is something to push.
  rm [--stale|--empty] <name>...
        Forget each workspace and delete its directory. Refuses the workspace
        you are standing in and the main workspace.
        --stale forgets every tracked workspace whose directory is gone from
        disk (and takes no names).
        --empty removes every other workspace whose working-copy commit has no
        changes, no description and no bookmark, and has no commits between it
        and trunk() (and takes no names).
  rm --self
        Forget and delete the current workspace (or the -R target). Refuses
        the main workspace. Your shell must cd out of the deleted directory.
  ls [--stale|--empty]
        List existing workspaces as <name><TAB><path>. --stale lists only those
        whose directory is gone from disk; --empty only those 'rm --empty'
        would remove (snapshotting each workspace to tell).
  root [<name>]
        Print the root of <name>, or of the main workspace if omitted.

Any <name> may carry the trailing "@" jj prints it with; it is dropped.
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
  jjq workspace list -T 'name ++ "\n"' | grep -Fx -- "$1" >/dev/null
}

# Workspace names are spelled "<name>@" in revsets, so that is how they appear
# in jj's own output and how they get copied onto our command line. Accept the
# suffix and drop it. jj does permit "@" inside a name, but it then quotes the
# name in template output, which ws_exists never matches — such a workspace is
# already beyond this tool's reach, so nothing is lost by stripping blind.
ws_name() { printf '%s\n' "${1%@}"; }

# Name of the workspace rooted at <dir>.
ws_name_at() {
  jj -R "$1" --ignore-working-copy workspace list \
    -T 'if(target.current_working_copy(), name ++ "\n")'
}

# Directory where workspace <name>'s files live: its jj-recorded path (jj
# >=0.38), or, in older repos that record no path, the main or current
# workspace root if it is one of those, else the convention path we would have
# created it at. Without the main/current check, the main workspace of an old
# repo would resolve to a nonexistent convention path and look stale.
ws_dir() {
  local root=$1 name=$2 current
  jjq workspace root --name "$name" 2>/dev/null && return 0
  if [ "$name" = "$(ws_name_at "$root")" ]; then
    printf '%s\n' "$root"
    return 0
  fi
  current=$(jjq workspace root)
  if [ "$name" = "$(ws_name_at "$current")" ]; then
    printf '%s\n' "$current"
    return 0
  fi
  ws_path "$root" "$name"
}

# A workspace is stale when it is tracked but its directory is gone from disk.
# ws_dir resolves the main and current workspaces to their (existing) roots, so
# this never flags a workspace that is unsafe to forget.
ws_stale() {
  [ ! -d "$(ws_dir "$1" "$2")" ]
}

# Prints "empty" when the workspace at <dir> holds no work: its working-copy
# commit has no changes, no description and no bookmark (the commit `jj
# workspace forget` abandons), and sits directly on trunk, with no commits of
# its own between the two. Anything else prints one line per commit in
# trunk()..@, capped at two since one past @ is enough to rule it out.
#
# Unlike jjq this snapshots <dir> first: otherwise edits jj has not seen yet
# leave the commit looking empty, and rm -rf would take them with the directory.
ws_emptiness() {
  jj -R "$1" log --no-graph -r 'trunk()..@' --limit 2 \
    -T 'if(empty && !description && !local_bookmarks, "empty", "nonempty") ++ "\n"'
}

# Whether workspace <name> is one `rm --empty` removes: not the main or current
# workspace (named <main-name> and <current-name>), with a jj-recorded path,
# still on disk, and holding no work by ws_emptiness. `ls --empty` asks the same
# question, so it previews exactly what rm would delete.
ws_empty() {
  local name=$1 main_name=$2 current_name=$3 path state
  [ "$name" != "$main_name" ] && [ "$name" != "$current_name" ] || return 1
  # As when removing by name: no rm -rf without a jj-recorded path.
  path=$(jjq workspace root --name "$name" 2>/dev/null) || {
    note "skipping '$name': no recorded path (repo predates jj 0.38)"
    return 1
  }
  # A missing directory makes the workspace stale, not empty; --stale handles
  # those.
  [ -d "$path" ] || return 1
  state=$(ws_emptiness "$path") || {
    note "skipping '$name': could not snapshot $path"
    return 1
  }
  [ "$state" = empty ]
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
  name=$(ws_name "$name")

  local root path
  root=$(repo_root)

  if ws_exists "$name"; then
    path=$(ws_dir "$root" "$name")
    [ -d "$path" ] ||
      die "workspace '$name' is tracked but $path is missing; run '$prog rm $name' to drop the stale entry, then retry"
    note "reusing workspace '$name' at $path"
    printf '%s\n' "$path"
    return 0
  fi

  if [ -z "$revset" ]; then
    local bookmark_name bookmark_revset matches
    bookmark_name=${name//\\/\\\\}
    bookmark_name=${bookmark_name//\"/\\\"}
    bookmark_revset="bookmarks(exact:\"$bookmark_name\")"
    matches=$(jjq log --no-graph -r "$bookmark_revset" -T 'commit_id ++ "\n"')
    [ -z "$matches" ] || revset=$bookmark_revset
  fi

  path=$(ws_path "$root" "$name")
  local add=(workspace add --name "$name")
  [ -z "$revset" ] || add+=(--revision "$revset")
  mkdir -p "$(dirname "$path")"
  jj -R "$root" "${add[@]}" "$path" >&2
  printf '%s\n' "$path"
}

cmd_rm() {
  # mode is the one bulk flag given (--self, --stale or --empty), if any.
  local mode="" name path
  local names=()
  while [ $# -gt 0 ]; do
    case $1 in
      --self | --stale | --empty)
        [ -z "$mode" ] || [ "$mode" = "$1" ] ||
          die "rm: $mode cannot be combined with $1"
        mode=$1
        shift
        ;;
      -*) die "rm: unknown option: $1" ;;
      *)
        names+=("$(ws_name "$1")")
        shift
        ;;
    esac
  done
  [ -z "$mode" ] || [ ${#names[@]} -eq 0 ] || die "rm: $mode takes no names"

  local root current
  root=$(repo_root)
  current=$(jjq workspace root)

  if [ "$mode" = --self ]; then
    [ "$current" != "$root" ] || die "rm: refusing to remove the main workspace"

    jj -R "$current" workspace forget
    cd "$root"
    rm -rf "$current"
    note "removed current workspace ($current); main workspace is $root"
    return 0
  fi

  if [ "$mode" = --stale ]; then
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

  if [ "$mode" = --empty ]; then
    local main_name current_name found=false
    main_name=$(ws_name_at "$root")
    current_name=$(ws_name_at "$current")
    while IFS= read -r name; do
      ws_empty "$name" "$main_name" "$current_name" || continue
      path=$(jjq workspace root --name "$name")
      jj -R "$root" workspace forget "$name"
      rm -rf "$path"
      note "removed empty workspace '$name' ($path)"
      found=true
    done < <(jjq workspace list -T 'name ++ "\n"')
    $found || note "no empty workspaces"
    return 0
  fi

  [ ${#names[@]} -gt 0 ] || die "rm: missing <workspace>..."

  # Validate every name before touching any, so a bad name late in the list
  # does not leave the earlier ones half-done.
  local paths=() recorded=()
  for name in "${names[@]}"; do
    ws_exists "$name" || die "rm: no such workspace: $name"
    path=$(ws_dir "$root" "$name")
    [ "$path" != "$current" ] || die "rm: refusing to remove the workspace you are in: $name"
    [ "$path" != "$root" ] || die "rm: refusing to remove the main workspace: $name"

    # The recorded path is authoritative, but it only exists for workspaces in
    # repos initialized with jj >=0.38. Older ones report "no recorded path",
    # and we will not `rm -rf` a directory we cannot confirm jj owns.
    if jjq workspace root --name "$name" >/dev/null 2>&1; then
      recorded+=(true)
    else
      [ ! -e "$path" ] ||
        die "rm: workspace '$name' has no recorded path (repo predates jj 0.38); delete its directory by hand, then run 'jj workspace forget $name'"
      recorded+=(false)
    fi
    paths+=("$path")
  done

  local i
  for i in "${!names[@]}"; do
    name=${names[$i]}
    path=${paths[$i]}
    jj -R "$root" workspace forget "$name"
    if ${recorded[$i]}; then
      rm -rf "$path"
      note "removed workspace '$name' ($path)"
    else
      # Nothing on disk to protect: this is a stale entry, so just forget it.
      note "forgot stale workspace '$name' (no directory on disk)"
    fi
  done
}

cmd_ls() {
  # filter is the one --stale or --empty given, if any.
  local filter=""
  while [ $# -gt 0 ]; do
    case $1 in
      --stale | --empty)
        [ -z "$filter" ] || [ "$filter" = "$1" ] ||
          die "ls: $filter cannot be combined with $1"
        filter=$1
        shift
        ;;
      -*) die "ls: unknown option: $1" ;;
      *) die "ls: unexpected argument: $1" ;;
    esac
  done

  local root name path main_name="" current_name=""
  root=$(repo_root)
  if [ "$filter" = --empty ]; then
    main_name=$(ws_name_at "$root")
    current_name=$(ws_name_at "$(jjq workspace root)")
  fi
  while IFS= read -r name; do
    case $filter in
      --stale) ws_stale "$root" "$name" || continue ;;
      --empty) ws_empty "$name" "$main_name" "$current_name" || continue ;;
    esac
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
  local name
  name=$(ws_name "$1")
  ws_exists "$name" || die "root: no such workspace: $name"
  jjq workspace root --name "$name" 2>/dev/null ||
    die "root: workspace '$name' has no recorded path (repo predates jj 0.38)"
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
