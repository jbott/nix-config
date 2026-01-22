#!/usr/bin/env bash
# Git wrapper for jj workspaces
# This script translates common git commands to jj equivalents when in a jj workspace
# that doesn't have a real .git directory (pure jj workspace)

# If jj is calling git internally, pass through to real git
parent_comm=$(ps -o comm= -p $PPID 2>/dev/null)
if [[ "$parent_comm" == "jj" ]]; then
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

# Helper to run jj with a warning for user-facing commands
jj_user() {
    echo "Warning: This is a jj workspace. Running: jj $*" >&2
    @jj@ "$@"
}

# Helper to run jj silently for machine-readable output
jj_silent() {
    @jj@ "$@"
}

# We're in a jj workspace, translate commands
case "$1" in
    rev-parse)
        shift
        case "$1" in
            --show-toplevel)
                jj_silent workspace root
                ;;
            --short=*)
                length="${1#--short=}"
                shift
                if [ "$1" = "HEAD" ]; then
                    jj_silent log -r @ --no-graph -T "commit_id.short($length)"
                else
                    # Handle arbitrary revisions
                    jj_silent log -r "${1:-@}" --no-graph -T "commit_id.short($length)"
                fi
                ;;
            --short)
                shift
                if [ "$1" = "HEAD" ]; then
                    jj_silent log -r @ --no-graph -T 'commit_id.short(7)'
                else
                    jj_silent log -r "${1:-@}" --no-graph -T 'commit_id.short(7)'
                fi
                ;;
            HEAD)
                jj_silent log -r @ --no-graph -T 'commit_id'
                ;;
            *)
                # Try to parse as a revision
                if [ -n "$1" ]; then
                    jj_silent log -r "$1" --no-graph -T 'commit_id' 2>/dev/null || echo "$1"
                else
                    jj_silent log -r @ --no-graph -T 'commit_id'
                fi
                ;;
        esac
        ;;

    status)
        shift
        if [ "$1" = "--porcelain" ]; then
            # Machine-readable: no warning
            # Return empty output if working copy is clean (to match git behavior)
            if jj_silent status 2>&1 | grep -q "The working copy has no changes"; then
                # Clean working copy
                exit 0
            else
                # Has changes - output a simple format
                # Just indicate there are changes
                echo "M  (working copy has changes)"
            fi
        else
            jj_user status "$@"
        fi
        ;;

    log)
        shift
        # Parse common git log flags
        format=""
        revision="@"
        num_commits=""

        while [ $# -gt 0 ]; do
            case "$1" in
                --format=*)
                    format="${1#--format=}"
                    shift
                    ;;
                -1)
                    num_commits="1"
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

    describe)
        shift
        if [ "$1" = "--tags" ] && [ "$2" = "--exact-match" ]; then
            # Machine-readable: check for tags on current commit
            tags=$(jj_silent log -r @ --no-graph -T 'tags')
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
            --get|--get-all|--list|--get-regexp)
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

    clone)
        # Forward to jj git clone
        shift
        jj_user git clone "$@"
        ;;

    push|pull|fetch)
        # Forward to jj git commands
        cmd="$1"
        shift
        jj_user git "$cmd" "$@"
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
