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

@test "filter strips leading ./" {
  run bash "$SCRIPT" --root "$FIX" --out "${BATS_TEST_TMPDIR}/dot.txt" ./corpora
  [ "$status" -eq 0 ]
  [ "$output" = "corpora" ]
}

@test "COLLECTION_FILTER env selects path" {
  run env COLLECTION_FILTER=works/1-1000 bash "$SCRIPT" \
    --root "$FIX" --out "${BATS_TEST_TMPDIR}/env.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "works/1-1000" ]
}

@test "empty tree fails" {
  run bash "$SCRIPT" --root "$EMPTY" --out "${BATS_TEST_TMPDIR}/none.txt"
  [ "$status" -ne 0 ]
}

@test "l1 skips sourceless orphan shards" {
  FIX_IHA="${BATS_TEST_DIRNAME}/fixtures/discover-iha"
  run bash "$SCRIPT" --root "$FIX_IHA" --mode l1 --out "${BATS_TEST_TMPDIR}/iha.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"works/1-1000"* ]]
  [[ "$output" != *"works/IHA"* ]]
  [[ "$output" != *"authority-files/new"* ]]
  [[ "$output" == *"authority-files/IHA"* ]]
}

@test "matrix mode emits corpus roots" {
  run bash "$SCRIPT" --root "$FIX" --mode matrix --out "${BATS_TEST_TMPDIR}/matrix.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"works"* ]]
  [[ "$output" == *"persons"* ]]
  [[ "$output" == *"corpora"* ]]
  [[ "$output" != *"works/1-1000"* ]]
}
