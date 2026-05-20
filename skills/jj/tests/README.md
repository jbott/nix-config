# jj Skill Tests

Pressure-tested scenarios for the sibling `skills/jj/SKILL.md`. Each scenario
builds a disposable jj repo, hands it to a subagent with the skill text and a
task, then verifies the resulting state.

## Layout

```
skills/jj/
  SKILL.md                          # the skill under test (sibling)
  tests/
    README.md                       # this file
    lib/common.sh                   # shared bash helpers (assert_*, init_repo, etc.)
    scenarios/
      NN-short-name/
        STATE.md                    # human-readable description of starting + expected state
        setup.sh                    # builds /tmp/jj-test/NN-short-name/ at the starting state
        prompt.md                   # task for the subagent (markdown, included verbatim)
        verify.sh                   # checks final state; exits 0 on pass, non-zero on fail
```

## Running a single scenario manually

```bash
cd skills/jj/tests/scenarios/01-commit-with-format
bash setup.sh                            # creates /tmp/jj-test/01-commit-with-format/
# ... do work in /tmp/jj-test/01-commit-with-format/ ...
bash verify.sh                           # exit 0 = pass
```

## Running the full suite via subagents

The runner script `lib/run-suite.sh` (added in a later phase) dispatches
ed3d-basic-agents subagents — one per scenario — passing them the SKILL.md
text, the scenario prompt, and the repo path. Each subagent works in its repo
in isolation and reports back. Then `verify.sh` runs per scenario.

## Scenario coverage

| # | Area | What it tests |
|---|---|---|
| 01 | Daily | Commit with `<prefix>: <verb> ...` message format |
| 02 | Daily | Stack two commits sequentially, both with correct format |
| 03 | Daily | Create a `john/<name>` bookmark after committing |
| 04 | Daily | Push current stack (alias awareness — `jj push`) |
| 05 | Daily | Read a large diff (should dispatch haiku subagent per skill) |
| 06 | Rebase | Reorder: swap B and C in `trunk → A → B → C → @` |
| 07 | Rebase | Move B onto `trunk()` directly, leaving A and C behind |
| 08 | Rebase | Rebase stack onto updated trunk via `jj rom` alias |
| 09 | Rebase | Bring sibling stack current via `jj restack` |
| 10 | Split | Split one commit (5 files, 3 logical groups) into 3 commits by file |
| 11 | Split | Split a file with two logical changes by hunk via `jj-hunk-tool` |
| 12 | Split | Split with `-p` to create parallel siblings instead of parent/child |
| 13 | Squash | Squash `@` into `@-` |
| 14 | Squash | Squash a fixup at `@` into a non-adjacent ancestor via `--from`/`--into` |
| 15 | Squash | Collapse three WIP commits into one, preserving the pre-WIP commit |
| 16 | Squash | Absorb scattered fixups by blame; review op log |
| 17 | Edge | Resolve a conflict that appeared after a rebase |
| 18 | Edge | Recover from a bad rewrite via `jj op restore` |
| 19 | Mental model | Tempted to use `jj describe` — should use `jj commit` instead |
| 20 | Mental model | Editor trap: subagent recovers when `JJ_EDITOR` fails by re-running with `-m` |
| 21 | Megamerge | Fold a commit above a megamerge into the merge as a new parent via `jj stage` |

## Conventions

- All test repos go under `/tmp/jj-test/<scenario>/`, never inside the source tree
- Scenarios must be idempotent: `setup.sh` deletes and recreates its repo
- `verify.sh` should print specific reasons on failure (`echo "FAIL: ..." >&2`)
- Source `lib/common.sh` for shared helpers
