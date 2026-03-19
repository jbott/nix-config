---
name: jj
description: "jj version control — use when asked to commit, describe, bookmark, split, or squash changes. Triggers: commit changes, create a commit, save my work, describe this commit, split commit, squash commits. Commands: /jj commit, /jj describe, /jj bookmark, /jj split, /jj squash"
---

# jj Reference Guide

Reference and operations for jj (Jujutsu) version control.

## Usage

Invoked as `/jj <command>`:
- `/jj commit` - Create a commit from working copy changes
- `/jj describe` - Generate and set a description for a commit
- `/jj bookmark` - Create a bookmark for the current commit
- `/jj split` - Split a commit into multiple commits by function
- `/jj squash` - Squash working copy changes into ancestor commits

## Commit Description Format

All commit descriptions MUST be a single line: `<project-prefix>: <short description>`

**IMPORTANT**: Never use multi-line descriptions or bullet points.

- **Project prefix**: path from the repo root to the most specific common directory of the changed files (e.g., `src/auth`, `lib/utils`, `services/api`)
- **Description**: starts with a lowercase verb: add, update, fix, refactor, remove, etc.

Examples: `src/auth: add JWT token refresh logic`, `lib/utils: fix date parsing for ISO formats`, `services/api: remove delay on sidebar tooltips`

## Analyzing Changes

```bash
jj diff --stat             # working copy: file names and line counts
jj diff --git              # working copy: full diff in git patch format
jj show <rev> --stat       # specific revision: file names and line counts
jj show <rev> --git        # specific revision: full diff in git patch format
```

Use `jj diff` for working copy (`@`), `jj show` for specific revisions.

Always use `--git` when reading diffs (not the default jj diff format).

- **Small changes** (≤5 files, ≤200 lines): read the diff directly
- **Large changes** (>5 files or >200 lines): use the Task tool with `model=haiku` to run the diff command and summarize the changes

## Operations

**Always provide `-m "<description>"`** to all commands that accept it — without it, jj opens an interactive editor which will hang. Since descriptions are always single-line, pass them directly as `-m "the message"` — do NOT use heredocs or `cat <<EOF`.

### `/jj commit`

1. Run `jj diff --stat` for overview (shows file names and line counts)
2. Analyze changes (small: `jj diff --git` directly; large: use haiku subagent to summarize)
3. Determine project prefix from file paths
4. Generate one-line description
5. Run `jj commit -m "<description>"`

After committing, `@` becomes an empty working copy on top of the new commit.

### `/jj describe`

1. Run `jj show <rev> --stat` for overview (use `@-` for parent)
2. Analyze changes (small: `jj show <rev> --git` directly; large: use haiku subagent to summarize)
3. Determine project prefix from file paths
4. Generate one-line description
5. Run `jj describe <rev> -m "<description>"`

### `/jj bookmark`

1. Run `jj log -r ::@ --limit 10` to see recent commits and understand the work theme
2. Generate a 2-4 word kebab-case name describing the work
3. Create bookmark:
   - If `@` is empty: `jj bookmark create john/<name> -r @-`
   - If `@` has changes: `jj bookmark create john/<name>`

Naming examples: `john/add-search-api`, `john/fix-login-redirect`, `john/refactor-db-queries`

### `/jj split`

1. Run `jj status` to check if splitting `@` (has changes) or `@-` (working copy empty)
2. Run `jj show <rev> --stat` for overview
3. Analyze changes (small: `jj show <rev> --git` directly; large: use haiku subagent to summarize)
4. Propose functional groups (feature+tests together, config separate, migrations separate, refactoring separate)
5. **Ask user for approval via AskUserQuestion**
6. Execute splits:
   ```bash
   jj split -r <rev> -m "<description>" file1 file2
   ```
7. Describe the last group (no split needed):
   ```bash
   jj describe -r @- -m "<description>"
   ```

**Note**: After each split, the revision ID changes. Use `@-` to refer to the result.

### `/jj squash`

1. Run `jj diff --stat` for overview (shows file names and line counts)
2. Run `jj log -r ::@- --limit 15` to see candidate ancestor commits
3. Analyze changes (small: `jj diff --git` directly; large: use haiku subagent to summarize)
4. **Match changes to ancestor commits by path and commit descriptions**
5. Execute squashes

**Basic**: `jj squash` moves all changes from `@` into `@-`.

**Squashing a revision into its parent** (`-r`):
```bash
jj squash -r <change-id> -m "<combined description>"
```
`-r <rev>` squashes that revision into its parent.

**IMPORTANT**: `-r` is incompatible with `--from`/`--into`. Use `-r` to squash a revision into its parent. Use `--from`/`--into` for flexible source→destination squashing.

**Squashing into a specific destination** (`--into`):
```bash
jj squash --into <change-id> -m "<description>"                   # all of @ into target
jj squash --into <change-id> -m "<description>" path/to/file.py   # specific files from @
jj squash --into <change-id> -m "<description>" "src/**/*.py"     # glob pattern from @
```

**Squashing from a specific source** (`--from`):
```bash
jj squash --from <change-id> -m "<description>"                              # squash source into @ (default --into @)
jj squash --from <change-id> --into <change-id> -m "<description>"           # arbitrary source → destination
```
`--from` is useful when you want to pull changes from a non-adjacent commit or combine `--from` with `--into` to squash between any two commits.

**Sub-file chunks** (specific hunks, not whole files):
1. Save original @ change ID: `jj log -r @ --no-graph -T 'change_id'`
2. Create intermediate: `jj new --insert-before @`
3. Write only the hunks for target commit
4. Squash: `jj squash --into <target-change-id>`
5. Return to rebased @: `jj edit <rebased-@-change-id>`
6. Remove duplicated hunks
7. Restore working copy: `jj new`

**Prefer bookmark names** (e.g., `john/app-deploy`) when a revision has one — they're human-readable and stable across rewrites. Fall back to **change IDs** (e.g., `ksrmwuon`) for revisions without bookmarks. Never use commit IDs — they change on every rewrite.

## Revision Syntax

| Syntax | Meaning |
|--------|---------|
| `@` | Current working copy commit |
| `x-` | Parent(s) of x (e.g., `@-` = parent of working copy) |
| `x+` | Children of x |
| `@--` | Grandparent (`@-` then `-` again) |
| `trunk()` | Main branch (main/master) |
| `::x` | All ancestors of x, including x |
| `x::` | All descendants of x, including x |
| `x..y` | Ancestors of y that are NOT ancestors of x |
| `x::y` | Descendants of x that are also ancestors of y |
| `<bookmark>` | Revision by bookmark name (e.g., `john/app-deploy`) — preferred |
| `<change-id>` | Revision by change ID (e.g., `ksrmwuon`) — fallback |

## Divergent Commits

When a change ID has divergent copies (shown as `<change-id>/0`, `<change-id>/1`), **always inspect both commits before taking action**. Run `jj show <change-id>/0 --git` and `jj show <change-id>/1 --git` to compare their contents. Only then decide which to abandon or how to resolve the divergence.

## Working Copy Behavior

- `@` (working copy) is often an empty commit on top of your actual work
- Check `jj log` for "(empty)" to know if @ has changes
- `jj commit` creates commit and leaves @ empty
- `jj describe` modifies existing commit, doesn't change @
