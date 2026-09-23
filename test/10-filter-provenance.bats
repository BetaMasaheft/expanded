#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/ci/filter-provenance.sh"

setup() {
  cat >"${BATS_TEST_TMPDIR}/sources.json" <<'EOF'
{
  "version": 1,
  "betmasweb": "web",
  "bibliography": "bib",
  "corpora": {
    "manuscripts": "mss",
    "works": "works-new",
    "narratives": "nar"
  }
}
EOF
  cat >"${BATS_TEST_TMPDIR}/provenance.json" <<'EOF'
{
  "version": 1,
  "betmasweb": "web",
  "bibliography": "bib",
  "corpora": {
    "manuscripts": "mss",
    "works": "works-old",
    "narratives": "nar"
  }
}
EOF
  printf '%s\n' \
    'manuscripts/Berlin' \
    'manuscripts/EMML/1-1000' \
    'works/1-1000' \
    'narratives' \
    >"${BATS_TEST_TMPDIR}/shards.txt"
  printf '%s\n' \
    'manuscripts/Gone' \
    'works/IHA' \
    'narratives/oldstory' \
    >"${BATS_TEST_TMPDIR}/removed.txt"
}

@test "drops corpora whose pins already match the publication" {
  run bash "$SCRIPT" \
    --shards "${BATS_TEST_TMPDIR}/shards.txt" \
    --removed "${BATS_TEST_TMPDIR}/removed.txt" \
    --sources "${BATS_TEST_TMPDIR}/sources.json" \
    --provenance "${BATS_TEST_TMPDIR}/provenance.json" \
    --out-shards "${BATS_TEST_TMPDIR}/out-shards.txt" \
    --out-removed "${BATS_TEST_TMPDIR}/out-removed.txt"
  [ "$status" -eq 0 ]
  [ "$(cat "${BATS_TEST_TMPDIR}/out-shards.txt")" = "works/1-1000" ]
  [ "$(cat "${BATS_TEST_TMPDIR}/out-removed.txt")" = "works/IHA" ]
}

@test "a new expander republishes every corpus" {
  jq '.betmasweb = "web-2"' "${BATS_TEST_TMPDIR}/sources.json" >"${BATS_TEST_TMPDIR}/sources-new.json"
  run bash "$SCRIPT" \
    --shards "${BATS_TEST_TMPDIR}/shards.txt" \
    --removed "${BATS_TEST_TMPDIR}/removed.txt" \
    --sources "${BATS_TEST_TMPDIR}/sources-new.json" \
    --provenance "${BATS_TEST_TMPDIR}/provenance.json" \
    --out-shards "${BATS_TEST_TMPDIR}/out-shards.txt" \
    --out-removed "${BATS_TEST_TMPDIR}/out-removed.txt"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/out-shards.txt" | tr -d ' ')" = "4" ]
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/out-removed.txt" | tr -d ' ')" = "3" ]
}

@test "a missing watermark publishes every shard" {
  run bash "$SCRIPT" \
    --shards "${BATS_TEST_TMPDIR}/shards.txt" \
    --removed "${BATS_TEST_TMPDIR}/removed.txt" \
    --sources "${BATS_TEST_TMPDIR}/sources.json" \
    --provenance "${BATS_TEST_TMPDIR}/no-such.json" \
    --out-shards "${BATS_TEST_TMPDIR}/out-shards.txt" \
    --out-removed "${BATS_TEST_TMPDIR}/out-removed.txt"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "${BATS_TEST_TMPDIR}/out-shards.txt" | tr -d ' ')" = "4" ]
}

@test "an empty corpus pin is not a match" {
  jq '.corpora.manuscripts = ""' "${BATS_TEST_TMPDIR}/sources.json" >"${BATS_TEST_TMPDIR}/sources-empty.json"
  run bash "$SCRIPT" \
    --shards "${BATS_TEST_TMPDIR}/shards.txt" \
    --removed "${BATS_TEST_TMPDIR}/removed.txt" \
    --sources "${BATS_TEST_TMPDIR}/sources-empty.json" \
    --provenance "${BATS_TEST_TMPDIR}/provenance.json" \
    --out-shards "${BATS_TEST_TMPDIR}/out-shards.txt" \
    --out-removed "${BATS_TEST_TMPDIR}/out-removed.txt"
  [ "$status" -eq 0 ]
  grep -qx 'manuscripts/Berlin' "${BATS_TEST_TMPDIR}/out-shards.txt"
  grep -qx 'manuscripts/Gone' "${BATS_TEST_TMPDIR}/out-removed.txt"
}
