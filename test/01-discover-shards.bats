#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/ci/discover-shards.sh"
FIX="${BATS_TEST_DIRNAME}/fixtures/discover"
EMPTY="${BATS_TEST_DIRNAME}/fixtures/discover-empty"

@test "discovers L1 works slices and corpora" {
  run bash "$SCRIPT" --root "$FIX" --out "${BATS_TEST_TMPDIR}/shards.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"works/1-1000"* ]]
  [[ "$output" == *"works/1001-2000"* ]]
  [[ "$output" == *"persons/alpha"* ]]
  [[ "$output" == *"corpora"* ]]
  [ -f "${BATS_TEST_TMPDIR}/shards.txt" ]
}

@test "filter emits single path" {
  run bash "$SCRIPT" --root "$FIX" --out "${BATS_TEST_TMPDIR}/one.txt" corpora
  [ "$status" -eq 0 ]
  [ "$output" = "corpora" ]
}

@test "empty tree fails" {
  run bash "$SCRIPT" --root "$EMPTY" --out "${BATS_TEST_TMPDIR}/none.txt"
  [ "$status" -ne 0 ]
}
