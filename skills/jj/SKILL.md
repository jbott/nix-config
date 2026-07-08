---
name: jj
description: Use when committing, inspecting, splitting, squashing, rebasing, or otherwise modifying history in this jj (Jujutsu) repo - covers jj's mental model, the path-prefix commit message format (NOT Conventional Commits), the editor traps that hang Claude's shell, John's aliases, and hunk-level surgery via jj-hunk-tool
---

# jj

The repo uses [Jujutsu](https://docs.jj-vcs.dev/). Use `jj`, not `git`. The
working directory is colocated with `.git/`, but git commands will fight jj's
operation log.

## Commit messages — required format (read this section every time)

Every commit message in this repo is `<path>: <verb> <description>`, where
`<path>` is the **filesystem path** (from repo root, slash-delimited) to the
most specific common directory of the files you changed.

Real examples from this repo's log:

```
machines/ha: open mosh UDP ports in firewall
common/nix: tune nix daemon settings for performance
common/packages: add mosh
services/home-assistant: enable mqtt broker
lib/utils: fix parse_iso to strip Z
```

**Procedure before running `jj commit -m "..."`, `jj describe -m "..."`, or
any other `-m` flag:**

1. Look at what changed (`jj diff --summary --no-pager`).
2. Take the common directory prefix of those paths. That is your `<path>`.
   - Files all under `services/api/`? → prefix is `services/api`.
   - Files all under `lib/utils/`? → prefix is `lib/utils`.
   - Files spanning `services/api/` and `services/web/`? → prefix is `services`.
3. Pick a lowercase verb (`add`, `update`, `fix`, `refactor`, `remove`,
   `rename`, `tune`, `pin`).
4. Compose `"<path>: <verb> <short description>"`. The path contains a
   slash (unless it is a top-level dir like `flake`). The path is not in
   parentheses. There is no Conventional-Commits-style type tag.

If `jj log --no-pager -n 5` shows commits that look different from your
draft — copy the existing pattern. Match what the repo already does.

## Mental model

- **Working copy is a commit.** Named `@`. There is no staging area; every file
  edit is part of `@` the moment jj snapshots (which it does at the start of
  every command).
- **"Clean" means `@` is empty.** After `jj commit`, jj creates a fresh empty
  `@` on top. Leaving it there is correct — do **not** abandon it.
- **Two IDs per commit.** *Change-id* (k-z hex, stable across rewrites — use
  this) vs *commit-id* (content hash, same as the git SHA in colocated repos,
  changes on every rewrite). Refer to revisions by bookmark or change-id.
- **Bookmarks ≠ branches.** Named pointers to commits. They do **not**
  auto-advance on `jj commit` (unlike git branches). They **do** follow
  rewrites. `jj tug` advances them manually.
- **Workspaces are separate working copies sharing one repo.** Each has its own
  `@`. In `jj log` a workspace's working copy renders as `<name>@` (trailing `@`,
  nothing after) — e.g. `default@`, `monover@`, `fix-command-ack@`. This is
  **not** a bookmark. A *bookmark* renders with no `@` (`john/foo`); a *remote*
  bookmark renders as `name@remote` (`john/foo@origin`). So `foo@` = workspace,
  `foo` = bookmark, `foo@origin` = remote bookmark. Don't treat a `<name>@` entry
  as a branch you can `jj push` or `jj tug` — it's another checkout. List them
  with `jj workspace list`; remove one with `jj wsrm <name>`.
  - **Every workspace's `@` is empty and mutable**, just like yours. So a revset
    like `empty() & mutable()` matches *other* workspaces' working copies too —
    `jj abandon` over it deletes another agent's/checkout's working copy out from
    under it. Always exclude them: `working_copies()` is the revset for "every
    workspace's `@`." Abandon only within your own stack — see the abandon-guard
    pitfall below.
- **Conflicts are data.** A commit can contain conflicts and still be rebased,
  squashed, pushed. They must be resolved before code compiles, but jj never
  blocks on them.
- **History edits are safe and routine.** jj auto-rebases descendants when you
  rewrite a commit. Watch the output for "N descendants now have conflicts" —
  resolve immediately, before they cascade.
- **Every command logs an operation.** The operation log is repo-wide and
  shared across all workspaces — so commands that rewrite it (`jj undo`,
  `jj op restore`) affect every workspace at once. Those two commands are
  user-invoked only; see the "Recovery" section below.

## Editor traps — structural and behavioral

The shell Claude runs in has no terminal. Any command that opens `$EDITOR` or
the diff editor hangs forever.

**Structural fix (already in place):** `JJ_EDITOR` is set to a script that
errors out. Any unflagged `jj commit / describe / squash / split` that tries to
open the description editor will fail with a clear message — re-run with `-m`.

**The diff editor is NOT covered by `JJ_EDITOR`.** It is `:builtin` (a TUI) by
default. Avoid these forms:

| Avoid | Use instead |
|---|---|
| `jj split` (no filesets → defaults to `-i`) | `jj split <files...> -m "msg"` *or* `jj-hunk-tool split <ids...> -m "msg"` |
| `jj diffedit` | `jj-hunk-tool diffedit <ids...> -r <rev>` |
| `jj squash -i`, `jj commit -i`, `jj restore -i` | drop `-i`; use filesets or `jj-hunk-tool` |
| `--tool <name>` (implies `-i`) | omit |

## John's aliases — prefer these

Defined in `home-manager/programs/jujutsu.nix`. They encode the workflow.

| Alias | What it does | When to reach for it |
|---|---|---|
| `jj push` | `jj git push -r '::@ & bookmarks()'` — push every bookmark in the ancestry of `@` | Publishing the current stack |
| `jj tug` | Advance the nearest bookmark to the latest non-empty commit in `::@` | After committing on a stack you want a bookmark to follow |
| `jj rom` | Rebase `@` and stack onto `trunk()`, skipping emptied commits | "Rebase onto main" |
| `jj restack` | Rebase all of your mutable stacks onto `trunk()` (current + orphan stacks, but never stacks anchored by another active workspace) | After trunk moved, to bring every local stack current at once |
| `jj dt` | `jj diff --git --from 'latest(heads(::@ & ::trunk()))' --to @` | Show the full diff of the current stack vs trunk |
| `jj lt` | `jj log -r 'trunk()..@' --summary` | Quick stack overview with file-level changes |
| `jj wsrm <ws>` | Forget a workspace and `rm -rf` its directory | Cleaning up a workspace |
| `jj stack <rev>` | Insert `<rev>` as a new sibling parent of `closest_merge(@)` — i.e. attach a branch to the megamerge | Adding a single change as a new branch of the megamerge |
| `jj stage` | Same as `jj stack closest_merge(@)+:: ~ empty()` — folds every non-empty commit above the megamerge into the merge as additional branches | One-shot consolidation of work done on top of a megamerge |

The repo auto-tracks `john/*` bookmarks on `origin` and `main|master|trunk` on
both `origin` and `upstream`, so newly-pushed bookmarks become tracked
automatically.

### Publishing a bookmark (branch)

```bash
# Already-tracked bookmark (any john/*, or one you've pushed before):
jj push                             # alias: pushes every bookmark ancestral to @

# Brand-NEW bookmark, not yet on origin — create it on @- and push in one step:
jj git push --named <name>=@-       # e.g. jj git push --named COM-924-foo=@-
# equivalently, if the bookmark already exists locally, push it by name:
jj git push --bookmark <name>       # explicit --bookmark creates it on the remote

# Bookmark exists on origin but your local copy isn't tracking it:
jj bookmark track <name>@origin && jj push
```

Why the extra step for a new bookmark: `auto-track-bookmarks` only auto-tracks
`main`/`master`/`trunk` and `john/*`, and `git.push-new-bookmarks` is off. So for
any other name (a `COM-924-…` ticket branch, say) the bare `jj push` alias
**refuses to create it** and prints:

```
Warning: Refusing to create new remote bookmark <name>@origin
Hint: Run `jj bookmark track <name> --remote=origin` and try again.
Nothing changed.
```

That is the signal to push explicitly with `--named` / `--bookmark` (above) —
**not** to add `--allow-new` (removed in this jj; it errors `unexpected argument
'--allow-new'`) or `--force` (jj force-with-leases automatically; on rejection
`jj git fetch` then re-push).

The `closest_merge(to)` revset alias (`heads(::to & merges())`) returns the
topmost merge commit ancestral to `to`. It backs `jj stack` / `jj stage` and is
useful any time you need to refer to the current megamerge.

Commit messages are always single-line. Pass them inline with `-m
"<path>: <verb> ..."`. Do not heredoc.

## Megamerges

A *megamerge* is an octopus merge (3+ parents) whose parents are the tips of
independent branches you have in flight. `@` sits on top of the merge, and the
working copy contains the union of every branch's work. Instead of switching
between branches, you edit on top of the megamerge and then route changes back
to the right parent.

When to use it:

- You're juggling several in-progress branches and want to see them all
  applied at once (integration testing, refactors that span branches).
- You want to avoid late merge conflicts: building on the merge surfaces
  conflicts immediately, so they're resolved once instead of N times.

Workflow:

```bash
# Build the megamerge once: merge the tips of every branch you're working on.
jj new <branch1-tip> <branch2-tip> <branch3-tip>

# Work normally. New commits land on top of the megamerge as a stack.
# When ready to route a single change back to one of the parent branches:
jj absorb                       # route by blame (fastest if hunks land cleanly)
# or for one specific commit:
jj squash --from <commit> --into <branch-tip>

# To insert a single revision as a new branch of the megamerge:
jj stack <rev>                  # rebase --after trunk() --before closest_merge(@) --revisions <rev>

# To fold every non-empty commit above the megamerge into the merge in one
# step (each becomes an additional parent branch):
jj stage                        # alias: jj stack closest_merge(@)+:: ~ empty()

# Keep the megamerge current as trunk advances:
jj restack                      # rebases your mutable stacks onto the new trunk
```

`jj stack` / `jj stage` require a merge commit in `::@`. If `closest_merge(@)`
resolves to nothing (no merge in your history), the alias errors — build the
megamerge first with `jj new <tip1> <tip2> ...`.

Pitfalls:

- The megamerge itself contains no diff vs its parents (it's the union).
  Don't try to `jj describe` it as if it were normal work; treat it as
  scaffolding.
- After `jj stage`, the original stacked commits on top of the merge are
  empty. Abandon them or let `jj rom` skip them next time.

## Day-to-day workflow

```bash
jj status                          # what's in @
jj diff --git --no-pager           # @ vs parent, git format
jj log --no-pager                  # graph; also useful to see existing commit-message style
jj commit -m "services/api: add user validation"   # finalize @, new empty @ on top
jj push                            # publish bookmarks (alias)
```

To start fresh work mid-session: `jj new` (creates an empty `@` on top of the
current `@`). After `jj commit`, this happens automatically.

## Inspecting

```bash
jj diff --git --no-pager                       # @ vs parent
jj diff --git --no-pager -r <rev>              # arbitrary revision
jj show --git --no-pager <rev>                 # description + diff
jj log --no-pager -r '<revset>' -p --git       # graph with patches
jj file annotate <path>                        # blame
```

Always pass `--git` (jj's default diff format is harder to parse) and
`--no-pager` (the pager hangs Claude's shell).

For diffs larger than ~5 files or ~200 lines, dispatch a haiku subagent to
summarize rather than reading the whole diff yourself.

### Reading `jj log` — what belongs to you vs another workspace

Bare `jj log` uses John's alias revset, which is already scoped to `@`,
**your** visible heads (`mine()`), tracked remote bookmarks, and `trunk()`. So
the default view rarely shows foreign commits. But the moment you pass `-r`
with a broad revset (`mutable()`, `empty()`, `all()`, `::@`), other workspaces'
commits appear — and they look like leftover junk you might be tempted to
abandon. They are not yours to touch. Annotated example:

```
@  vupuxmzt john@host 2026-06-25 … e67fc96b   ← YOUR working copy (the @ node)
│  (empty) (no description set)
○  znkkpsru john@host 2026-06-25 … john/fix-login a1b2c3d4   ← your commit; john/fix-login is a BOOKMARK
│  services/auth: fix login redirect
│ ○  ovkroqrz codebot@host 2026-06-25 … codebot@ 7b90ac42   ← ANOTHER workspace's @ (label codebot@). DO NOT abandon.
├─╯  (empty) (no description set)
◆  pozypntq john@host 2026-06-25 … main john/fix-login@origin 8c132424   ← immutable trunk; main / …@origin are bookmarks
│  nix: flake update
```

Reading rules:

- The `@` **node symbol** (leftmost) = *your* working copy. Exactly one per log.
- A `<name>@` **ref label** (in the commit's ref list, e.g. `codebot@`) = *another
  workspace's* working copy. The trailing-`@`-nothing-after is the tell. It is
  another live checkout — never `jj abandon`, `jj push`, or `jj tug` it.
- Don't confuse the **author email** `john@host` / `codebot@host` (always has a
  host after the `@`) with a `<name>@` ref (nothing after the `@`).
- `name` (no `@`) = local bookmark. `name@origin` = remote bookmark.
- An empty `(no description set)` commit that is **another workspace's `@`** is
  that workspace's clean state — abandoning it is the bug, not the cleanup.

To see exactly which commits are foreign working copies:
`jj log -r 'working_copies() ~ @' --no-pager`.

## Comparing rewrites

After amending, squashing, rebasing, or absorbing, you often want to verify
"what did my change actually become?" — separate from any drift in its parent.

```bash
jj interdiff --from <old> --to <new> --git --no-pager                # patches of <old> vs <new>, normalized to same base
jj interdiff --from john/foo@origin --to john/foo --git --no-pager   # what changed since last push
jj evolog -p --git --no-pager -r <rev>                               # whole evolution of <rev>, every rewrite
```

`jj interdiff` rebases `--from` onto `--to`'s parents and diffs the result
against `--to`. The output is "how the patches differ," not "how file contents
differ." Use this when `<old>` and `<new>` have different parents — a plain
`jj diff --from A --to B` would also include the parent drift, which interdiff
strips out.

`jj evolog -p` shows the full chain across every rewrite of a change, with the
same parent normalization applied between each adjacent pair.

Typical moment to reach for these: after `jj rom`, `jj squash`, `jj describe`,
or `jj-hunk-tool absorb`, before `jj push` — verify the rewrite did what you
intended. `<bookmark>@origin` is the canonical `--from` for "since last push".

## Describing and editing existing revisions

```bash
jj describe -m "<msg>"             # set/update description on @ (does NOT advance @)
jj describe <rev> -m "<msg>"       # describe a specific revision
jj edit <rev>                      # set <rev> as @ to edit it in place
jj new                             # when done editing, return to a fresh empty @
```

`jj describe` modifies in place — it is **not** a commit. To finalize a change,
use `jj commit -m "..."`, which describes `@` and then creates a new empty `@`.

## Splitting (file-level)

```bash
jj split <files...> -m "<msg for the selected commit>"
```

The selected files become a new commit (`@-` after the split), the rest stays
where the original commit lived. Always provide **both** filesets **and** `-m`.

`-p` makes the two halves siblings instead of parent/child. `-A <rev>` /
`-B <rev>` insert the selected part elsewhere in the graph.

## Splitting / squashing / restoring (hunk-level)

`jj-hunk-tool` is the non-interactive equivalent of jj's interactive hunk ops.
It assigns each hunk a stable 7-char ID derived from path + content.

```bash
jj-hunk-tool hunks                         # list hunks in @ with IDs and line ranges
jj-hunk-tool hunks -r <rev>                # hunks in any revision
jj-hunk-tool hunks --file <path>           # filter to one file
jj-hunk-tool patch <id> <id>:5-30          # unified diff of selected hunks (line ranges optional)
jj-hunk-tool split <id>... -m "<msg>"      # split selected hunks into a new commit
jj-hunk-tool squash <id>... -m "<msg>"     # squash hunks into parent (or --from/--into)
jj-hunk-tool restore <id>...               # discard selected hunks
jj-hunk-tool diffedit <id>... -r <rev>     # keep only selected hunks in <rev>
jj-hunk-tool absorb [--dry-run]            # auto-route hunks to mutable ancestors by blame
```

Hunk IDs are stable as long as the diff content hasn't changed. If lookup
fails, re-run `hunks` for fresh IDs. Line ranges: `id:5-30,40-50`.

## Squashing

```bash
jj squash -m "<msg>"                                   # @ into @-
jj squash -r <rev> -m "<msg>"                          # <rev> into its parent
jj squash --from <src> --into <dst> -m "<msg>"         # arbitrary mutable src → dst
```

`-r` is incompatible with `--from`/`--into`. Pass file paths to squash only
those files; use `jj-hunk-tool squash` for sub-file hunks.

## Absorbing

```bash
jj absorb                                  # auto-distribute @ into mutable ancestors by blame
jj-hunk-tool absorb --dry-run              # preview hunk-level routing plan
jj-hunk-tool absorb                        # execute (hunk-aware, treats each hunk atomically)
```

`jj-hunk-tool absorb` is stricter than `jj absorb`: pure insertions and
ambiguous hunks (touching lines from multiple ancestors) stay in `@`. Always
review with `jj op show -p --no-pager` after.

## Rebasing and reordering

```bash
jj rebase -r <rev> -d <dest>           # single commit
jj rebase -s <rev> -d <dest>           # commit + descendants
jj rebase -b <rev> -d <dest>           # whole containing branch
jj rebase -r <rev> -A <after>          # reorder: insert <rev> after <after>
jj rebase -r <rev> -B <before>         # reorder: insert <rev> before <before>
```

To rebase the current stack onto trunk, prefer `jj rom`. To bring sibling
stacks current after a trunk move, `jj restack`.

If a rebase produces conflicts, jj prints a warning and embeds the conflict in
the rewritten commit. Resolve before doing further rewrites — cascading
conflicts are painful.

## Recipes

End-to-end walkthroughs for the cases that bite. Each one assumes a colocated
repo and an empty `@` on top of the stack.

### Split one commit into N commits

`@-` touches 5 files: 2 for feature X, 2 for bug Y, 1 unrelated refactor. Goal:
3 separate commits.

```bash
jj split -r @- featureX_a.py featureX_b.py -m "src/x: add feature X"
# Original change-id now holds {featureX_a, featureX_b} with the new message.
# A new commit on top (now at @-) holds {bugY_a, bugY_b, refactor.py} with
# the original description.
jj split -r @- bugY_a.py bugY_b.py -m "src/y: fix Y race"
# Now the bug-Y commit sits between feature X and the refactor leftover.
jj describe -r @- -m "src/foo: extract shared helper"
```

After each `jj split`, the **selected** files stay at the original change-id
(with the new `-m` message); the **remaining** files go into a new commit on
top (which keeps the original description). The new commit becomes `@-`, so
keep splitting `@-` until what's left is the final group, then `jj describe`
it.

**Ordering tip:** the *first* piece you split off ends up at the *bottom* of
the resulting stack (furthest from `@`), the *last* describe at the top. If
the final order matters for your stack, peel pieces off in bottom-to-top
order.

### Split one file into multiple commits by hunk

`src/api.py` has a bugfix interleaved with an unrelated cleanup.

```bash
jj-hunk-tool hunks --file src/api.py
# →  a1b2c3d  src/api.py:12-28  (the bugfix)
#    e4f5g6h  src/api.py:55-71  (the cleanup)
jj-hunk-tool split a1b2c3d -m "src/api: fix retry backoff"
jj describe -r @- -m "src/api: extract retry helper"
```

### Reorder commits in a stack

Stack: `trunk → A → B → C` with `@` on `C`. You want B and C swapped.

```bash
jj rebase -r B -A C        # move B to after C; jj rebases dependent commits
```

If reordering creates a conflict (because C depended on B), jj warns. Resolve
before going further.

### Move a commit onto a different parent

Stack: `trunk → A → B → C`. Commit `B` actually belongs straight on trunk, not
on top of `A`.

```bash
jj rebase -r B -d 'trunk()'    # JUST B moves; A and C stay where they are (C is rebased without B)
jj rebase -s B -d 'trunk()'    # B and its descendants C move together
```

`-r` rewrites one commit; `-s` rewrites that commit plus everything that
depends on it.

### Squash a fixup into the right ancestor

`@` is a typo fix for commit `pqrs` two commits down the stack.

```bash
jj squash --from @ --into pqrs -m "src/auth: add JWT refresh logic"
```

The `@`'s changes merge into `pqrs`; `@` is left empty. Pass the combined
description with `-m`.

If you have multiple fixups scattered through `@` and aren't sure which
ancestor each belongs to, let absorb route by blame:

```bash
jj-hunk-tool absorb --dry-run    # preview routing
jj-hunk-tool absorb              # execute
jj op show -p --no-pager         # review what landed where
```

Anything that absorb can't route confidently (pure insertions, ambiguous
hunks) stays in `@`. Handle those manually with `jj squash --from @ --into
<rev>`.

### Squash a chain of WIP commits into one

Stack: `trunk → A → wip1 → wip2 → wip3 → @`. Goal: collapse the three WIP
commits into a single commit on top of `A`, leaving `trunk → A → single → @`.

```bash
jj squash -r wip3 -m "src/feat: add complete feature"   # wip3 into wip2
jj squash -r wip2 -m "src/feat: add complete feature"   # wip2 (now containing wip3) into wip1
# Stop here. wip1 now holds everything; A is preserved.
```

**Don't squash one more step** — `jj squash -r wip1` would collapse wip1
into `A`, which is usually not what you want.

Equivalent with `--from`/`--into` (non-adjacent collapse, same result):
```bash
jj squash --from wip3 --into wip1 -m "src/feat: add complete feature"
jj squash --from wip2 --into wip1 -m "src/feat: add complete feature"
```

### Rebase the current stack onto updated trunk

```bash
jj rom           # rebase @ and its ancestors-on-stack onto trunk(), skip emptied
```

To bring sibling stacks (not the one `@` is on) current too:

```bash
jj restack
```

### Recover from a bad rewrite

`jj undo` and `jj op restore` are user-invoked only — see the "Recovery"
section. For scoped recovery you can do on your own, use `jj abandon <rev>`,
`jj restore <path>`, `jj revert -r <rev> -d @`, or just redo the rewrite.

## Bookmarks

```bash
jj bookmark create john/<kebab-case> -r @-     # @ is empty after commit, so point at @-
jj bookmark create john/<kebab-case>            # if @ itself has the work
jj bookmark list --no-pager
jj bookmark delete john/<name>
jj tug                                          # advance nearest bookmark (alias)
```

Names: `john/<2-4 word kebab description>`, e.g. `john/add-search-api`,
`john/fix-login-redirect`. Auto-tracked on push.

A `<name>@` in `jj log` (trailing `@`, e.g. `monover@`) is a **workspace**, not a
bookmark — see the Mental model section. `jj bookmark list` shows the real
bookmarks; `jj workspace list` shows workspaces.

## Conflicts

```bash
jj log -r 'conflicts()' --no-pager     # find conflicted commits
jj resolve --list                       # list conflicted files in @
jj resolve --list -r <rev>             # in a specific revision
```

Resolve by reading the conflicted file and editing out jj's conflict markers
(they have 3 sides — diff form — not 2 like git). Save the file; jj snapshots
it automatically and the conflict clears.

## Recovery — `jj undo` and `jj op restore` are USER-INVOKED ONLY

**Do NOT run `jj undo` or `jj op restore` yourself.** These rewrite the
repo-wide operation log. You cannot reliably detect concurrent activity
(another workspace, the user's other shell, an editor auto-snapshotting, a
file watcher), so running these blind can silently discard unrelated work.

**Run them only if the user, in this conversation, explicitly tells you to
run `jj undo` or `jj op restore`.** Phrases like "fix it", "recover", "undo
that", or "get it back" do NOT count as explicit permission — they're
instructions to solve the problem, not authorization to use these specific
commands.

### What to do when something went wrong

1. `jj op log --no-pager -n 10` — find the op id of the state to restore to.
2. `jj op show -p --no-pager <op-id>` — confirm what that op contains.
3. Report the situation to the user with the proposed recovery command (e.g.
   `jj op restore <op-id>`). Stop. Let the user run it.

### Scoped recovery that IS safe to run on your own

These don't touch the op log:

```bash
jj abandon <rev>                       # drop a revision, rebase descendants
jj restore <path>                      # restore files in @
jj revert -r <rev> -d @                # create a reverse-patch on top of @
```

Or just redo the rewrite you intended.

### Rationalizations — do not act on these

| Excuse | Reality |
|---|---|
| "jj undo is cheap" | It rewrites the shared op log; under concurrent activity it may revert the wrong op or discard another workspace's snapshot. |
| "The user is asleep / build is breaking / I'm on autopilot" | None of that authorizes you to run undo/op-restore. Surface the op-id and stop. |
| "There's only one workspace right now" | You can't verify this. `jj op log` will show snapshots from any concurrent process. |
| "I'll just undo the most recent op, that's the safe one" | The most recent op may be a snapshot from another workspace — `jj undo` would undo *that*, not your mistake. |
| "I can recover non-destructively, the op log won't actually lose anything" | The rule is not 'safe vs unsafe' — it is 'you don't run these without explicit permission'. |

## Revsets cheat-sheet

| Syntax | Meaning |
|---|---|
| `@`, `@-`, `@--` | working copy, parent, grandparent |
| `<change-id>` / `<bookmark>` | named revision |
| `trunk()` | default-branch head |
| `::x`, `x::` | ancestors / descendants (inclusive) |
| `x..y` | y's ancestors minus x's |
| `x & y`, `x \| y`, `~x`, `x ~ y` | intersect, union, complement, difference |
| `mutable()`, `mine()`, `empty()`, `conflicts()` | predicates |
| `working_copies()` | every workspace's `@` — exclude before bulk `abandon` |
| `reachable(@, mutable())` | your current stack (commits reachable from `@` within mutable) |
| `roots(s)`, `heads(s)`, `ancestors(s, n)` | functions |
| `description("substring")` | match by description |

Full grammar: `jj help revsets`.

## Pitfalls

- `jj describe` ≠ `jj commit`. `describe` rewrites in place and leaves `@`
  holding your changes. To finalize, use `jj commit -m`.
- After a rewrite, change-ids stay; commit-ids change. Never refer to a
  revision by commit-id across rewrites.
- Divergent change-ids appear as `<id>/0`, `<id>/1`. Inspect both
  (`jj show --git -r <id>/0`) before abandoning either.
- Immutable commits (on trunk, tags, remote bookmarks) can't be rewritten —
  jj refuses with an error. Use `mutable()` revset to find what's editable.
- `jj squash` without args squashes `@` into `@-`. With `--from`/`--into` it
  moves changes between any two mutable revisions.
- **Never bulk-abandon empty commits by a broad predicate.** `jj abandon
  '(empty() & mutable()) ~ @'` looks like a tidy sweep but it deletes *other
  workspaces'* working copies (each is empty + mutable) and unrelated empty
  commits scattered through unpushed local history when `origin` is far behind.
  Both are not yours. Empty commits are not garbage — a fresh `@` is *supposed*
  to be empty (don't abandon it), and the next `jj rom` / `jj restack` skips
  emptied commits in your own stack automatically. If you genuinely must drop
  empties:
  - Scope to your own stack, not all of `mutable()`:
    `jj abandon -r 'reachable(@, mutable()) & empty() ~ working_copies()'`
    (`trunk()..@ & empty()` works too for a linear stack).
  - Always exclude `working_copies()`, never just `@` — `~ @` still catches
    every *other* workspace's working copy.
  - When in doubt, abandon specific change-ids you have inspected, one revset
    at a time, rather than a category.
