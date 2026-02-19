---
name: jj
description: "jj version control: /jj commit, /jj describe, /jj bookmark, /jj split, /jj squash"
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

- **Project prefix**: descriptive folder path for the subsystem (e.g., `src/auth`, `lib/utils`, `services/api`)
- **Description**: starts with a lowercase verb: add, update, fix, refactor, remove, etc.

Examples: `src/auth: add JWT token refresh logic`, `lib/utils: fix date parsing for ISO formats`, `db/migrations: add users table`

## Analyzing Changes

```bash
jj diff --summary          # files changed with change type
jj diff --stat             # lines changed per file histogram
jj diff --git              # full diff in git patch format
jj show <rev> --summary    # for a specific revision
jj diff -r <rev> --stat    # stats for a specific revision
jj show <rev> --git        # full diff for a revision in git patch format
```

Always use `--git` when reading diffs (not the default jj diff format).

- **Small changes** (≤5 files, ≤200 lines): read the diff directly
- **Large changes** (>5 files or >200 lines): use the Task tool with `model=haiku` to run the diff command and summarize the changes

## Operations

### `/jj commit`

1. Run `jj diff --summary` and `jj diff --stat` for overview
2. Analyze changes (small: `jj diff --git` directly; large: use haiku subagent to summarize)
3. Determine project prefix from file paths
4. Generate one-line description
5. Run `jj commit -m "<description>"`

After committing, `@` becomes an empty working copy on top of the new commit.

### `/jj describe`

1. Run `jj show <rev> --summary` and `jj diff -r <rev> --stat` (use `@-` for parent)
2. Analyze changes (small: `jj diff -r <rev> --git` directly; large: use haiku subagent to summarize)
3. Determine project prefix from file paths
4. Generate one-line description
5. Run `jj describe <rev> -m "<description>"`

### `/jj bookmark`

1. Run `jj log -r ::@ --limit 10` to see recent commits and understand the work theme
2. Generate a 2-4 word kebab-case name describing the work
3. Create bookmark:
   - If `@` is empty: `jj bookmark create john/<name> -r @-`
   - If `@` has changes: `jj bookmark create john/<name>`

Naming examples: `john/s3-inventory-download`, `john/fix-auth-refresh`, `john/refactor-poller-config`

### `/jj split`

1. Run `jj status` to check if splitting `@` (has changes) or `@-` (working copy empty)
2. Run `jj show <rev> --summary` and `jj diff -r <rev> --stat` for overview
3. Analyze changes (small: `jj diff -r <rev> --git` directly; large: use haiku subagent to summarize)
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

1. Run `jj diff --summary` and `jj diff --stat` for overview
2. Run `jj log -r ::@- --limit 15` to see candidate ancestor commits
3. Analyze changes (small: `jj diff --git` directly; large: use haiku subagent to summarize)
4. **Match changes to ancestor commits by path and commit descriptions**
5. Execute squashes

**Basic**: `jj squash` moves all changes from `@` into `@-`.

**Targeted**:
```bash
jj squash --into <change-id> path/to/file.py  # specific files
jj squash --into <change-id> "src/**/*.py"    # glob pattern
jj squash --into @--                           # grandparent
```

**Sub-file chunks** (specific hunks, not whole files):
1. Save original @ change ID: `jj log -r @ --no-graph -T 'change_id'`
2. Create intermediate: `jj new --insert-before @`
3. Write only the hunks for target commit
4. Squash: `jj squash --into <target-change-id>`
5. Return to rebased @: `jj edit <rebased-@-change-id>`
6. Remove duplicated hunks
7. Restore working copy: `jj new`

**Always use change IDs** (e.g., `ksrmwuon`) not commit IDs - they're stable across rewrites.

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
| `<change-id>` | Specific commit by change ID (e.g., `ksrmwuon`) |

## Working Copy Behavior

- `@` (working copy) is often an empty commit on top of your actual work
- Check `jj log` for "(empty)" to know if @ has changes
- `jj commit` creates commit and leaves @ empty
- `jj describe` modifies existing commit, doesn't change @
