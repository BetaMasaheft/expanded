# BetaMasaheft expanded data

Generated TEI: source corpora from BetMasData, expanded by BetMasWeb
(`expand:file` / `makeExpand`), and published here for the eXist data image.

The package installs to `/db/apps/expanded` (see `repo.xml`). BetMasWeb’s
`$config:data-root` points at that collection — not at the raw
`/db/apps/BetMasData/*` source packages.

## Layout

| Path | Role |
| --- | --- |
| `manuscripts/`, `works/`, `persons/`, … | Expanded TEI corpora |
| `collection.xconf` | Lucene + range indexes (incl. computed `@quantity` fields) |
| `expath-pkg.xml` / `repo.xml` / `pre-install.xql` | eXist package metadata |
| `scripts/ci/` | Offline-safe helpers used by re-expand workflows (+ bats) |
| `test/` | Fixture bats for those scripts |
| `.github/workflows/` | Validate, smoke, re-expand, notify-betmas |

CI scripts, tests, and editor/agent dirs are **not** packed into the xar
(see `build.xml` excludes).

## Build the xar

```shell
ant xar   # → build/expanded-<version>.xar
```

## Re-expand via GitHub Actions

Workflow: [Scheduled Re-expansion](.github/workflows/re-expand.yml)
(`workflow_dispatch` only — not on a cron).

### Dispatch (CLI)

From a clone with `gh` authenticated to BetaMasaheft/expanded:

```shell
# Dry-run: full hybrid, no push (inspect assemble in the run UI / artifacts)
gh workflow run "Scheduled Re-expansion" --ref main \
  -f shard_mode=hybrid \
  -f push_to_main=false \
  -f allow_partial_assemble=false

# Pilot one collection
gh workflow run "Scheduled Re-expansion" --ref main \
  -f collection=corpora \
  -f push_to_main=false

# Production push (main only; all shards must succeed)
gh workflow run "Scheduled Re-expansion" --ref main \
  -f shard_mode=hybrid \
  -f push_to_main=true \
  -f allow_partial_assemble=false
```

Watch / download:

```shell
gh run list --workflow=re-expand.yml --limit 5
gh run watch          # after picking a run id, or: gh run watch <id>
gh run view <id> --web
```

### Dispatch (UI)

Actions → **Scheduled Re-expansion** → **Run workflow** → choose branch
(usually `main`) → set inputs → **Run workflow**.

### What the workflow does

1. Discover shards (`scripts/ci/discover-shards.sh`)
2. Each shard boots `ghcr.io/betamasaheft/betamasaheft:release-expanded`,
   runs makeExpand, exports with `xst`, uploads an artifact
3. Assemble merges artifacts (`scripts/ci/assemble-shards.sh`)
4. Optional `push_to_main` (blocked if any shard failed or partial assemble)
5. Push to `main` triggers [notify-betmas](.github/workflows/notify-betmas.yml)
   → BetMas rebuilds `betmas-data` / app images

### Shard modes

| Mode | Grain | Typical job count |
| --- | --- | --- |
| `hybrid` (default) | L1 for works / persons / manuscripts / places / institutions; matrix for the rest | ~174 |
| `l1` | Every L1 dir (skips sourceless orphans e.g. `authority-files/new`) | ~204 |
| `matrix` | One job per corpus root | ~9 (works/persons/manuscripts hit the 240 min limit) |

`allow_partial_assemble=true` is for dry-run inspection only; it always blocks
`push_to_main`.

## Re-expand locally

Prefer CI for a full corpus run (many hours, ~12 GB image, large exports).
Locally, mirror one CI shard (or loop the hybrid manifest) against a throwaway
container.

### 1. Boot the app image

```shell
docker pull ghcr.io/betamasaheft/betamasaheft:release-expanded
docker rm -f betmas-expand 2>/dev/null || true
docker run -d --name betmas-expand -p 8080:8080 \
  ghcr.io/betamasaheft/betamasaheft:release-expanded

# wait until REST answers (or until logs show "Server has started")
until curl -fsS -u admin: --max-time 3 http://localhost:8080/exist/rest/db/ >/dev/null 2>&1; do
  sleep 5
done

export EXISTDB_SERVER=http://localhost:8080 EXISTDB_USER=admin EXISTDB_PASS=
```

Needs GHCR read access for the private/org image (`docker login ghcr.io`).

### 2. Expand one BetMasData collection

Source lives under `/db/apps/BetMasData/…`; expand writes into
`/db/apps/expanded/…`.

```shell
rel=corpora   # or works/1-1000, manuscripts/EMML, …
col="/db/apps/BetMasData/${rel}"

out=$(curl -fsS -u admin: --get --max-time 0 \
  "http://localhost:8080/exist/rest/db/apps/BetMasWeb/modules/makeExpand.xql" \
  --data-urlencode "collection=${col}")
echo "${out}"
bash scripts/ci/check-makeExpand-output.sh "${out}"
```

### 3. Export and stage into this repo

```shell
export_root=$(mktemp -d)
artifact_root=$(mktemp -d)

xst get "/db/apps/expanded/${rel}" "${export_root}"
bash scripts/ci/stage-shard-export.sh \
  --rel "${rel}" \
  --export-root "${export_root}" \
  --artifact-root "${artifact_root}"

# Merge one shard into the working tree (rsync --delete for that path)
printf '%s\n' "${rel}" > /tmp/shards.txt
bash scripts/ci/assemble-shards.sh \
  --manifest /tmp/shards.txt \
  --shards-in "${artifact_root}" \
  --repo-root .
```

### 4. Full local hybrid (optional)

Same loop CI uses — expect a long wall-clock and large disk use:

```shell
bash scripts/ci/discover-shards.sh --mode hybrid --out /tmp/shards.txt --root .
mkdir -p /tmp/shards-in

while IFS= read -r rel; do
  [ -z "${rel}" ] && continue
  col="/db/apps/BetMasData/${rel}"
  echo "=== ${rel} ==="
  out=$(curl -fsS -u admin: --get --max-time 0 \
    "http://localhost:8080/exist/rest/db/apps/BetMasWeb/modules/makeExpand.xql" \
    --data-urlencode "collection=${col}")
  bash scripts/ci/check-makeExpand-output.sh "${out}"

  export_root=$(mktemp -d)
  xst get "/db/apps/expanded/${rel}" "${export_root}"
  bash scripts/ci/stage-shard-export.sh \
    --rel "${rel}" \
    --export-root "${export_root}" \
    --artifact-root /tmp/shards-in
  rm -rf "${export_root}"
done < /tmp/shards.txt

bash scripts/ci/assemble-shards.sh \
  --manifest /tmp/shards.txt \
  --shards-in /tmp/shards-in \
  --repo-root .
```

Tear down: `docker rm -f betmas-expand`.

Do **not** commit/push `main` from a partial local run unless you have
validated the tree (`xmllint` / RNG below).

## Local script tests

```shell
bats test/*.bats
shellcheck scripts/ci/*.sh
```

## Validation

Schema for expanded TEI:
[`tei-betamesaheft-expanded.rng`](https://github.com/BetaMasaheft/Schema/blob/master/tei-betamesaheft-expanded.rng)
(BetaMasaheft/Schema).

Well-formedness / RNG (same flags as CI):

```shell
# well-formedness
find . -name '*.xml' -not -path './.git/*' -not -path './test/*' -print0 \
  | xargs -0 -n50 xmllint --noout

# against expanded RNG (adjust SCHEMA path)
SCHEMA=../Schema/tei-betamesaheft-expanded.rng
find . -name '*.xml' -not -path './.git/*' -not -path './test/*' -print0 \
  | xargs -0 -n50 xmllint --noout --xinclude --nowarning --relaxng "$SCHEMA"
```

Legacy error hunts (often fixed by re-expand):

```shell
grep -l 'source-url' --include='*.xml' -r . > source-url_report.txt
find . -type f -name '*.xml' | xargs xmllint --noout 2>&1 | tee wellformedness-report.txt
```

```xpath
//*[namespace-uri() != 'http://www.tei-c.org/ns/1.0']
```
