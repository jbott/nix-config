#!/usr/bin/env bash
# Git wrapper for jj workspaces
# This script translates common git commands to jj equivalents when in a jj workspace
# that doesn't have a real .git directory (pure jj workspace)

# If jj is calling git internally, pass through to real git
parent_comm=$(ps -o comm= -p $PPID 2>/dev/null)
if [[ "$parent_comm" == "jj" ]]; then
    exec @git@ "$@"
fi

# `git clone` creates a new repo somewhere else; it's unrelated to the
# current jj workspace, so always pass through to real git.
if [[ "$1" == "clone" ]]; then
    exec @git@ "$@"
fi

# `git init` creates a fresh, independent repo (same rationale as clone) — e.g.
# buck2's external-cell fetch does `git init` in a buck-out scratch dir, then
# fetches into it. Once that dir has a real .git, the `rev-parse --git-dir`
# check below already routes further commands to real git, so only `init`
# needs to be allowed here.
if [[ "$1" == "init" ]]; then
    exec @git@ "$@"
fi

# `git -C <dir> ...` explicitly targets another directory's repo (buck2 and
# other tools use this to manage their own scratch repos). Let real git handle
# it against that dir rather than intercepting for the current jj workspace.
if [[ "$1" == "-C" ]]; then
    exec @git@ "$@"
fi

# Check if we're in a directory with a real .git directory
# If so, use real git (this includes colocated jj+git repos)
if @git@ rev-parse --git-dir &>/dev/null; then
    exec @git@ "$@"
fi

# Check if we're in a jj workspace (without .git)
if ! @jj@ workspace root &>/dev/null; then
    # Not in a jj workspace either, use real git (will likely fail, but that's expected)
    exec @git@ "$@"
fi

# glab >= 1.87 caches the canonical remote under
# remote.<name>.glab-resolved-{head,base}. If the read returns empty it
# tries `git config --add` to populate the cache, which fails in a jj
# workspace (no .git/config to write to). Inject the values via git's
# env-config layer so real git's reads (--get-all, --get-regexp) return
# them and glab skips the write entirely.
injected_configs=(
    "remote.origin.glab-resolved-head=head"
    "remote.origin.glab-resolved-base=base"
    "remote.origin.glab-resolved=head"
)
for i in "${!injected_configs[@]}"; do
    export "GIT_CONFIG_KEY_$i=${injected_configs[i]%%=*}"
    export "GIT_CONFIG_VALUE_$i=${injected_configs[i]#*=}"
done
export GIT_CONFIG_COUNT=${#injected_configs[@]}

# Helper to run jj with a warning for user-facing commands
jj_user() {
    echo "Warning: This is a jj workspace. Running: jj $*" >&2
    @jj@ "$@"
}

# Helper to run jj silently for machine-readable output
jj_silent() {
    @jj@ "$@"
}

# Strip leading `-c key=value` config-override flags before the subcommand.
# Tools like glab pass these to set transport/credential options that don't
# apply to jj — drop them so we dispatch on the real subcommand.
while [[ "$1" == "-c" ]]; do
    shift  # drop -c
    shift  # drop the key=value
done

# We're in a jj workspace, translate commands
case "$1" in
    rev-parse)
        shift
        case "$1" in
            --show-toplevel)
                jj_silent workspace root
                ;;
            --abbrev-ref)
                shift
                rev="${1:-HEAD}"
                if [ "$rev" = "HEAD" ]; then
                    rev="@-"
                fi
                # Get bookmark names on the revision; fall back to "HEAD" (detached)
                bookmarks=$(jj_silent log -r "$rev" --no-graph -T 'bookmarks.map(|b| b.name()).join(" ")')
                if [ -n "$bookmarks" ]; then
                    # Return the first bookmark
                    echo "${bookmarks%% *}"
                else
                    echo "HEAD"
                fi
                ;;
            --short=*)
                length="${1#--short=}"
                shift
                if [ "$1" = "HEAD" ]; then
                    jj_silent log -r @- --no-graph -T "commit_id.short($length)"
                else
                    # Handle arbitrary revisions
                    jj_silent log -r "${1:-@-}" --no-graph -T "commit_id.short($length)"
                fi
                ;;
            --short)
                shift
                if [ "$1" = "HEAD" ]; then
                    jj_silent log -r @- --no-graph -T 'commit_id.short(7)'
                else
                    jj_silent log -r "${1:-@-}" --no-graph -T 'commit_id.short(7)'
                fi
                ;;
            HEAD)
                jj_silent log -r @- --no-graph -T 'commit_id'
                ;;
            *)
                # Try to parse as a revision
                if [ -n "$1" ]; then
                    jj_silent log -r "$1" --no-graph -T 'commit_id' 2>/dev/null || echo "$1"
                else
                    jj_silent log -r @- --no-graph -T 'commit_id'
                fi
                ;;
        esac
        ;;

    status)
        shift
        # Parse the flags that select git's machine-readable output. Callers
        # parse this, so unrecognized flags error out rather than silently
        # producing output that ignores them.
        machine=0
        show_branch=0
        paths=()
        while [ $# -gt 0 ]; do
            case "$1" in
                -s|--short|--porcelain|--porcelain=1|--porcelain=v1)
                    machine=1
                    ;;
                -b|--branch)
                    show_branch=1
                    ;;
                -sb|-bs)
                    machine=1
                    show_branch=1
                    ;;
                -u*|--untracked-files=*)
                    # jj snapshots every non-ignored file into @, so there is no
                    # tracked/untracked distinction to tune. Accept and ignore.
                    ;;
                --long)
                    machine=0
                    ;;
                --)
                    shift
                    paths+=("$@")
                    break
                    ;;
                -*)
                    echo "git status $1: not supported in jj wrapper" >&2
                    exit 1
                    ;;
                *)
                    paths+=("$1")
                    ;;
            esac
            shift
        done

        if [ "$machine" -eq 0 ]; then
            jj_user status "${paths[@]}"
            exit $?
        fi

        # jj log filters commits by path, not the reported diff, so a pathspec
        # would be silently dropped from the file list below.
        if [ "${#paths[@]}" -gt 0 ]; then
            echo "git status: pathspec filtering is not supported in jj wrapper" >&2
            exit 1
        fi

        if [ "$show_branch" -eq 1 ]; then
            # git prints "## <branch>...<upstream> [ahead N, behind M]".
            # HEAD is @- (the working copy's parent), as elsewhere in this wrapper.
            bookmarks=$(jj_silent log -r @- --no-graph -T 'bookmarks.map(|b| b.name()).join(" ")')
            bm="${bookmarks%% *}"
            if [ -z "$bm" ]; then
                echo "## HEAD (no branch)"
            else
                # Upstream is a tracked remote bookmark of the same name that
                # has actually been pushed (`present`); an unpushed bookmark has
                # no remote ref to compare against, like a git branch with no
                # upstream. The colocated "git" remote is jj-internal rather
                # than a real remote, so skip it; prefer origin when several
                # match.
                upstream=""
                for remote in $(jj_silent bookmark list -a \
                    -T 'if(remote && tracked && present && remote != "git", name ++ "\t" ++ remote ++ "\n")' \
                    | awk -F'\t' -v b="$bm" '$1 == b { print $2 }'); do
                    if [ "$remote" = "origin" ]; then
                        upstream="origin"
                        break
                    fi
                    [ -z "$upstream" ] && upstream="$remote"
                done

                if [ -z "$upstream" ]; then
                    echo "## $bm"
                else
                    ahead=$(jj_silent log -r "${bm}@${upstream}..@-" --no-graph -T '"x\n"' 2>/dev/null | wc -l | tr -d ' ')
                    behind=$(jj_silent log -r "@-..${bm}@${upstream}" --no-graph -T '"x\n"' 2>/dev/null | wc -l | tr -d ' ')
                    tracking=""
                    if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
                        tracking=" [ahead $ahead, behind $behind]"
                    elif [ "$ahead" -gt 0 ]; then
                        tracking=" [ahead $ahead]"
                    elif [ "$behind" -gt 0 ]; then
                        tracking=" [behind $behind]"
                    fi
                    echo "## ${bm}...${upstream}/${bm}${tracking}"
                fi
            fi
        fi

        # Working-copy changes are the diff of @ against its parent, which is
        # what `jj status` reports. jj auto-snapshots, so every change is
        # already effectively staged: git's index column carries the status and
        # the worktree column stays blank.
        jj_silent log -r @ --no-graph \
            -T 'diff.files().map(|f| f.status() ++ "\t" ++ f.source().path() ++ "\t" ++ f.target().path() ++ "\n").join("")' \
            | while IFS=$'\t' read -r st src dst; do
                case "$st" in
                    "")       continue ;;
                    added)    printf 'A  %s\n' "$dst" ;;
                    modified) printf 'M  %s\n' "$dst" ;;
                    removed)  printf 'D  %s\n' "$dst" ;;
                    renamed)  printf 'R  %s -> %s\n' "$src" "$dst" ;;
                    copied)   printf 'C  %s -> %s\n' "$src" "$dst" ;;
                    *)        printf 'M  %s\n' "$dst" ;;
                esac
            done
        ;;

    log)
        shift
        # Parse common git log flags
        format=""
        revision="@-"

        while [ $# -gt 0 ]; do
            case "$1" in
                --format=*)
                    format="${1#--format=}"
                    shift
                    ;;
                -1)
                    # Ignored - jj log -r shows single revision by default
                    shift
                    ;;
                *)
                    # Assume it's a revision
                    if [ -n "$1" ] && [ "$1" != "HEAD" ]; then
                        revision="$1"
                    fi
                    shift
                    ;;
            esac
        done

        # Map format strings to jj templates
        case "$format" in
            %s)
                # Machine-readable: commit subject/message
                jj_silent log -r "$revision" --no-graph -T 'description.first_line()'
                ;;
            %H)
                # Machine-readable: full commit hash
                jj_silent log -r "$revision" --no-graph -T 'commit_id'
                ;;
            %h)
                # Machine-readable: short commit hash
                jj_silent log -r "$revision" --no-graph -T 'commit_id.short(7)'
                ;;
            *)
                # User-facing
                jj_user log -r "$revision"
                ;;
        esac
        ;;

    symbolic-ref)
        # Read the symbolic ref HEAD via jj. Mirrors `rev-parse --abbrev-ref`
        # but uses symbolic-ref's output format (refs/heads/<name>) and
        # exit conventions (exit 1 on detached HEAD, not echo "HEAD").
        shift
        short=0
        quiet=0
        while [[ "$1" == --* || "$1" == -q ]]; do
            case "$1" in
                --short) short=1 ;;
                --quiet|-q) quiet=1 ;;
            esac
            shift
        done
        rev="${1:-HEAD}"

        # glab and similar tools query refs/remotes/origin/HEAD to discover
        # the remote's default branch. jj clones don't create that symref,
        # so without this branch glab falls back to its hardcoded `master`
        # and `glab mr create` fails on main-default repos. Resolve via
        # jj's remote bookmarks, preferring main and falling back to master.
        if [ "$rev" = "refs/remotes/origin/HEAD" ]; then
            for candidate in main master; do
                if jj_silent log -r "${candidate}@origin" --no-graph -T 'commit_id' &>/dev/null; then
                    if [ "$short" -eq 1 ]; then
                        echo "origin/$candidate"
                    else
                        echo "refs/remotes/origin/$candidate"
                    fi
                    exit 0
                fi
            done
            [ "$quiet" -eq 0 ] && echo "fatal: ref refs/remotes/origin/HEAD is not a symbolic ref" >&2
            exit 1
        fi

        [ "$rev" = "HEAD" ] && rev="@-"
        bookmarks=$(jj_silent log -r "$rev" --no-graph -T 'bookmarks.map(|b| b.name()).join(" ")')
        bm="${bookmarks%% *}"
        if [ -n "$bm" ]; then
            if [ "$short" -eq 1 ]; then
                echo "$bm"
            else
                echo "refs/heads/$bm"
            fi
        else
            [ "$quiet" -eq 0 ] && echo "fatal: ref HEAD is not a symbolic ref" >&2
            exit 1
        fi
        ;;

    describe)
        shift
        if [ "$1" = "--tags" ] && [ "$2" = "--exact-match" ]; then
            # Machine-readable: check for tags on current commit
            tags=$(jj_silent log -r @- --no-graph -T 'tags')
            if [ -n "$tags" ] && [ "$tags" != "@│~" ]; then
                echo "$tags"
            else
                echo "fatal: no tag exactly matches '@'" >&2
                exit 128
            fi
        else
            echo "git describe: only --tags --exact-match HEAD is supported in jj wrapper" >&2
            exit 1
        fi
        ;;

    config)
        shift
        # Handle git config operations selectively
        case "$1" in
            --get|--get-all)
                exec @git@ config "$@"
                ;;
            --list|--get-regexp)
                # Read-only operations, proxy to real git
                exec @git@ config "$@"
                ;;
            --global|--system)
                # Non-local settings, proxy to real git
                exec @git@ config "$@"
                ;;
            --local)
                # Local repository settings - only ignore specific ones
                shift
                case "$1" in
                    core.hooksPath|core.hookspath)
                        # Git hooks don't apply to jj, silently ignore
                        exit 0
                        ;;
                    core.abbrev)
                        # Short hash length config, silently ignore
                        exit 0
                        ;;
                    *)
                        # Everything else - show error
                        echo "Error: This is a jj workspace at: $(jj_silent workspace root)" >&2
                        echo "git config --local '$1' is not supported" >&2
                        exit 1
                        ;;
                esac
                ;;
            core.hooksPath|core.hookspath|core.abbrev)
                # Direct config setting without --local/--global flag (defaults to --local)
                # Silently ignore these specific settings
                exit 0
                ;;
            *)
                # Unknown operation or setting - show error
                echo "Error: This is a jj workspace at: $(jj_silent workspace root)" >&2
                echo "git config '$1' is not supported" >&2
                exit 1
                ;;
        esac
        ;;

    add)
        echo "Error: This is a jj workspace at: $(jj_silent workspace root)" >&2
        echo "git add is not supported. In jj, all changes are automatically tracked in the working copy (@)" >&2
        exit 1
        ;;

    commit)
        echo "Error: This is a jj workspace at: $(jj_silent workspace root)" >&2
        echo "git commit is not supported. In jj:" >&2
        echo "  - Changes are automatically committed to the working copy (@)" >&2
        echo "  - Use 'jj describe' to set the commit message" >&2
        echo "  - Use 'jj new' to create a new commit" >&2
        exit 1
        ;;

    reset)
        echo "Error: This is a jj workspace at: $(jj_silent workspace root)" >&2
        echo "git reset is not supported. In jj, use 'jj restore' or 'jj edit' instead" >&2
        exit 1
        ;;

    rebase)
        echo "Error: This is a jj workspace at: $(jj_silent workspace root)" >&2
        echo "git rebase is not supported. Use 'jj rebase' instead" >&2
        exit 1
        ;;

    merge)
        echo "Error: This is a jj workspace at: $(jj_silent workspace root)" >&2
        echo "git merge is not supported. Use 'jj merge' or 'jj rebase' instead" >&2
        exit 1
        ;;

    checkout|switch)
        echo "Error: This is a jj workspace at: $(jj_silent workspace root)" >&2
        echo "git $1 is not supported. Use 'jj edit' to switch commits" >&2
        exit 1
        ;;

    branch)
        echo "Error: This is a jj workspace at: $(jj_silent workspace root)" >&2
        echo "git branch is not supported. Use 'jj bookmark' instead" >&2
        exit 1
        ;;

    stash)
        echo "Error: This is a jj workspace at: $(jj_silent workspace root)" >&2
        echo "git stash is not supported. In jj, changes are automatically tracked in @" >&2
        echo "Use 'jj new' to start a new commit instead" >&2
        exit 1
        ;;

    push|pull|fetch)
        # Forward to jj git commands
        cmd="$1"
        shift
        jj_user git "$cmd" "$@"
        ;;

    remote)
        shift
        case "$1" in
            -v|--verbose)
                # Reformat jj output to match git remote -v format
                jj_silent git remote list | while read -r name url; do
                    printf '%s\t%s (fetch)\n' "$name" "$url"
                    printf '%s\t%s (push)\n' "$name" "$url"
                done
                ;;
            "")
                # List remote names only
                jj_silent git remote list | while read -r name _; do
                    echo "$name"
                done
                ;;
            *)
                echo "Error: This is a jj workspace at: $(jj_silent workspace root)" >&2
                echo "git remote $1 is not supported. Use 'jj git remote' instead" >&2
                exit 1
                ;;
        esac
        ;;

    --version|version)
        # Read-only version query (cocoapods et al. parse `git --version`).
        # No repo state involved, so pass straight through to real git.
        exec @git@ "$@"
        ;;

    --help|-h|help)
        # Read-only help output (usage text, man pages). No repo state
        # involved, so pass straight through to real git.
        exec @git@ "$@"
        ;;

    diff)
        shift
        jj_user diff "$@"
        ;;

    show)
        shift
        jj_user show "$@"
        ;;

    *)
        echo "git $1: command not supported in jj wrapper" >&2
        echo "You're in a jj workspace at: $(jj_silent workspace root)" >&2
        echo "Try using 'jj' commands directly instead" >&2
        exit 1
        ;;
esac
