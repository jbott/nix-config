---
name: commit-scope
description: "Assign Linux-style logical subsystem prefixes (such as api/*, worker/*, infra/*, docs/*, build, skills) to commit messages instead of literal common-directory paths. Use whenever running jj commit, jj describe, jj split, or jj squash, or when classifying or rewriting commit subjects."
---

# Commit Scope

Commits use `<subsystem>: <verb> <description>` with a **logical subsystem
prefix**, overriding any literal common-directory heuristic (which collapses
`src/` + `tests/` or `docs/` + `CHANGELOG.md` to `.:`).

- Single line, lowercase imperative verb (`add`, `fix`, `align`, `narrow`,
  `preserve`, `replace`, `support`, `remove`, `refactor`, `document`, `update`).
- Never use `.` as `<subsystem>`, and never use Conventional Commits (`feat:`,
  `fix:`, `chore:`).

Examples from `jj log`:

```text
api/auth: rotate refresh-token signing keys without dropping active sessions
api/db: preserve tenant RLS context across pooled Postgres checkouts
api/billing: reconcile proration credits, voided invoices, and webhook retries
api: replace legacy per-route rate limits with tenant_quotas middleware
worker/ingest: bound S3 batch concurrency and checkpoint cursor lag
infra/terraform: split read-replica parameter group by environment
docs/ops: document zero-downtime Postgres major-version cutover
```

## Scoping Procedure

Inspect `jj diff --stat --no-pager` (or `jj log --no-pager --stat -r <rev>` when
classifying existing commits) and check `jj log --no-pager -n 20` to reuse
subsystem names already established in the repository. Then apply these three
steps:

### 1. Strip ancillary files (Primary-Change Principle)

Companion files follow the primary change rather than broadening scope:

- **Code commits** (commits modifying application, worker, library, or infra code):
  - Test suites and fixtures (`tests/**`, `testdata/**`, `*_test.*`) inherit the
    subsystem under test (use `tests` only when a commit modifies *only* test
    files or test harness code).
  - Build, packaging, and ignore manifests (`.gitignore`, `.dockerignore`,
    `Dockerfile`, `pyproject.toml`, `uv.lock`, `Cargo.toml`, `Cargo.lock`,
    `package.json`) are ancillary when paired with code changes.
  - Companion documentation (`docs/**`, `README.md`, `CHANGELOG.md`) is
    ancillary when updated alongside executable code changes.
  - Application wiring glue — such as route mounting in `src/relay_api/app.py`,
    CLI registration in `src/relay_api/cli.py`, table/migration registries in
    `src/relay_api/schema.py`, shared base types in `src/relay_api/types.py`, or
    feature-flag entries in `src/relay_api/config.py` — is ancillary when wiring
    up a domain module. Treat those files as substantive only when the commit's
    main purpose is changing routing, CLI plumbing, schema infrastructure, or
    configuration itself.
- **Docs-only commits**:
  - `CHANGELOG.md` and `TODO.md` are ancillary when paired with `docs/**`.
  - Root `README.md`, `AGENTS.md`, `CLAUDE.md`, and `ARCHITECTURE.md` (or docs
    navigation manifests like `mkdocs.yml`) are ancillary when touched as minor
    index or status syncs (`<=25%` of changed lines) alongside focused `docs/**`
    pages.

### 2. Map substantive files to leaf subsystems

Derive logical `<area>/<leaf>` (or standalone top-level) names from component
role and domain rather than raw wrapper directories:

- Strip language and package layout boilerplate (`src/<pkg>/`, `crates/`,
  `internal/`, `packages/`) down to the logical component (`api`, `worker`,
  `web`, `cli`, `sdk`).
- Group sibling implementation, model, serializer, and handler files for one
  domain into a single leaf (for example, `{billing,invoices,payouts}.py` ->
  `api/billing`).
- Use flat top-level scopes (`tests`, `build`, `ci`, `skills`) for standalone
  repository-wide tooling.

Illustrative mapping for a hypothetical service repository:

| Subsystem | Substantive paths |
|---|---|
| `api/auth` | `src/relay_api/{auth,sessions,tokens,oauth}.py` |
| `api/db` | `src/relay_api/{db,pool,migrations,audit}.py` |
| `api/quotas` | `src/relay_api/{quotas,config}.py` (rate limits, tenant entitlements, feature gates) |
| `api/webhooks` | `src/relay_api/{webhooks,signatures,deliveries}.py` |
| `api/billing` | `src/relay_api/{billing,invoices,payouts,billing_models}.py` |
| `worker/ingest` | `src/relay_worker/{ingest,checkpoints,s3_reader}.py` |
| `worker/dispatch` | `src/relay_worker/{dispatch,retries,dead_letter}.py` |
| `infra/terraform` | `infra/terraform/**` |
| `docs/api` | `docs/{http-api,webhooks,auth}.md`, `openapi/**` |
| `docs/ops` | `docs/ops/**`, `docs/runbooks/**` |
| `tests` | `tests/**` (test-only commits) |
| `build` | Standalone `.gitignore`, `.dockerignore`, `Dockerfile`, `pyproject.toml`, `uv.lock` |
| `ci` | `.github/workflows/**` |
| `skills` | `.agents/skills/**`, `.claude/skills/**` |

### 3. Apply the 70% / 250-line roll-up

- Use the leaf subsystem when it accounts for **>=70%** of substantive changed
  lines **and** no second peer leaf has **>=250** changed lines.
- Otherwise roll up one level to the parent area — such as **`api`**
  (cross-cutting or multi-domain server work), **`worker`** (cross-pipeline
  background job changes), **`infra`**, or **`docs`** (cross-cutting
  documentation, root architecture, or governance guides).
- If substantive changes still span multiple top-level areas (for example, `api`
  and `worker`), split independent changes into separate commits or scope to the
  component defining the contract rather than falling back to `.`.
