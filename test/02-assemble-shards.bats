#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/ci/assemble-shards.sh"
FIX="${BATS_TEST_DIRNAME}/fixtures/assemble"

setup() {
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "${REPO}/corpora"
  cp -a "${FIX}/repo-root/corpora/." "${REPO}/corpora/"
}

@test "merges shard and deletes stale xml" {
  run bash "$SCRIPT" \
    --manifest "${FIX}/manifest.txt" \
    --shards-in "${FIX}/shards-in" \
    --repo-root "$REPO"
  [ "$status" -eq 0 ]
  [ -f "${REPO}/corpora/new.xml" ]
  [ ! -f "${REPO}/corpora/old.xml" ]
}

@test "refuses zero-xml shard" {
  run bash "$SCRIPT" \
    --manifest "${FIX}/manifest-empty.txt" \
    --shards-in "${FIX}/shards-in-empty" \
    --repo-root "$REPO"
  [ "$status" -ne 0 ]
  [ -f "${REPO}/corpora/old.xml" ]
}

@test "refuses missing shard" {
  run bash "$SCRIPT" \
    --manifest "${FIX}/manifest-missing.txt" \
    --shards-in "${FIX}/shards-in" \
    --repo-root "$REPO"
  [ "$status" -ne 0 ]
}
