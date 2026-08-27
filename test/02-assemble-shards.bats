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

@test "refuses empty manifest" {
  : > "${BATS_TEST_TMPDIR}/empty-manifest.txt"
  run bash "$SCRIPT" \
    --manifest "${BATS_TEST_TMPDIR}/empty-manifest.txt" \
    --shards-in "${FIX}/shards-in" \
    --repo-root "$REPO"
  [ "$status" -ne 0 ]
  [ -f "${REPO}/corpora/old.xml" ]
}

@test "validates all shards before any rsync" {
  # Good corpora + empty sibling: must not merge corpora before failing.
  printf '%s\n' 'corpora' 'empty' > "${BATS_TEST_TMPDIR}/mixed.txt"
  shards="${BATS_TEST_TMPDIR}/shards-mixed"
  mkdir -p "${shards}/corpora" "${shards}/empty"
  cp -a "${FIX}/shards-in/corpora/." "${shards}/corpora/"
  run bash "$SCRIPT" \
    --manifest "${BATS_TEST_TMPDIR}/mixed.txt" \
    --shards-in "$shards" \
    --repo-root "$REPO"
  [ "$status" -ne 0 ]
  [ -f "${REPO}/corpora/old.xml" ]
  [ ! -f "${REPO}/corpora/new.xml" ]
}
