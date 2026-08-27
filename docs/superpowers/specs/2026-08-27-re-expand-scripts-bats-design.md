# Design: re-expand thin scripts + fixture bats

**Status:** draft for review  
**Date:** 2026-08-27  
**Repo:** BetaMasaheft/expanded  
**Related:** [expanded#11](https://github.com/BetaMasaheft/expanded/issues/11), [expanded#13](https://github.com/BetaMasaheft/expanded/pull/13)

## Goal

Extract the offline-safe bash from the matrix re-expand workflows into thin, locally runnable scripts covered by fixture-based bats tests — without blocking merge/pilot of #13.

## Non-goals

- Do **not** change [expanded#13](https://github.com/BetaMasaheft/expanded/pull/13) for this work. #13 merges and pilots with inline workflow bash as shipped.
- Do **not** put docker / GHCR login / image pull / eXist boot / `curl` makeExpand / `npx xst` into scripts in this PR (scope **A**).
- Do **not** add maximize-build-space or other runner-only steps to scripts.
- Do **not** cite `.cursor/plans/` in public CI/PR text.

## Sequencing

1. Merge + pilot #13 (`collection=corpora`, `push_to_main=false`, then larger slices).
2. Open a **follow-up PR** (new branch / worktree) that extracts scripts, adds bats, and rewires workflows to call the scripts.
3. Base the follow-up on `main` **after** #13 lands (or rebase a parallel branch off #13 tip onto post-merge `main` before opening the PR).

## Architecture

Workflows remain the orchestrator for GHA/docker/network. Scripts own pure filesystem / string contracts that are dangerous if wrong (`rsync --delete`, empty-shard wipe, makeExpand output parsing, shard path staging).

```
plan job          → scripts/ci/discover-shards.sh
expand-shard job  → (YAML: docker/curl/xst) + scripts/ci/check-makeExpand-output.sh
                  → scripts/ci/stage-shard-export.sh   # after xst has written a local tree
assemble job      → scripts/ci/assemble-shards.sh
                  → (YAML: git diff / commit / push unchanged)
```

## Script contracts

### `scripts/ci/discover-shards.sh`

- **Input:** working tree rooted at expanded checkout (or `--root DIR`). Optional filter: env `COLLECTION_FILTER` or first positional arg (single relative path).
- **Behavior:** If filter set, emit that one path. Else discover L1 dirs under `works|persons|places|institutions|narratives|studies|authority-files|manuscripts` plus top-level `corpora` if present (same rules as #13 plan job).
- **Output:** one relative path per stdout line; write `shards.txt` (path configurable, default `./shards.txt`); exit non-zero if zero shards.
- **Caller (GHA):** wraps jq/`GITHUB_OUTPUT` for matrix JSON (keep jq in workflow or a tiny companion — prefer keep matrix JSON assembly in workflow to avoid GHA coupling in the script).

### `scripts/ci/check-makeExpand-output.sh`

- **Input:** makeExpand response body via stdin or `"$1"`.
- **Behavior:** accept only `expanded <N> …` with N ≥ 1; reject `expanded 0 …` and any other shape.
- **Output:** exit 0 / 1; message on stderr suitable for `::error::` prefix by caller if desired.

### `scripts/ci/stage-shard-export.sh`

- **Input:** `--rel PATH` (e.g. `works/1-1000`), `--export-root DIR` (xst download parent), `--artifact-root DIR` (e.g. `shard-out`).
- **Behavior:** locate xst leaf dir (`export-root/<leaf>`), rsync into `artifact-root/<rel>/`, delete `__contents__.xml`, write `.shard-manifest` line, refuse if zero `*.xml`.
- **Does not** invoke xst.

### `scripts/ci/assemble-shards.sh`

- **Input:** `--manifest FILE`, `--shards-in DIR`, `--repo-root DIR`.
- **Behavior:** for each manifest line, require `shards-in/<rel>` with ≥1 xml; `mkdir -p` + `rsync -a --delete`; strip `__contents__.xml` and `.shard-manifest` under repo-root; fail if any shard missing/empty.
- **Does not** git commit/push.

## Testing

- **Runner:** bats-core (install via apt/npm/git in CI; document local `bats test`).
- **Layout:** `test/01-discover-shards.bats` … `04-stage-shard-export.bats`; fixtures under `test/fixtures/` (tiny fake trees, a few empty/non-empty xml files).
- **Coverage targets:** happy path; empty filter discovery; missing shard; zero-xml refuse (assemble + stage); makeExpand `0` / garbage / success; path normalization (`./` strip).
- **Out of scope for bats:** live eXist, GHCR, artifact upload.

## CI (follow-up PR)

- Add a job on `pull_request` (and optionally `push`) that installs bats and runs `bats test`.
- Keep existing Validate PR / Install smoke unchanged except calling scripts from re-expand workflows.
- Optional: `shellcheck scripts/ci/*.sh` in the same job (nice-to-have, not required for first land).

## Error handling

- All scripts: `set -euo pipefail`.
- Prefer explicit `echo … >&2` + `exit 1` over silent failure.
- Assemble/stage must never rsync `--delete` from an empty or missing source.

## Worktree / branch

- Isolated git worktree under `.worktrees/` (add to `.gitignore` if missing).
- Branch name suggestion: `dp-re-expand-scripts-bats`.
- Open as a new PR against `main` after #13 merge; link #11.

## Success criteria

- `bats test` passes offline with no docker/secrets.
- `re-expand.yml` / `reusable-expand-shard.yml` contain no duplicated discover/assemble/stage/check logic (thin `run: bash scripts/ci/…`).
- Pilot path unchanged in behavior vs #13 for the same inputs (behavior-preserving extract).
