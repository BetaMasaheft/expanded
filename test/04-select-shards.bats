#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/ci/select-shards.sh"

@test "missing-only keeps paths absent from the checkout" {
  root="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$root/manuscripts/BNF"
  printf '%s\n' "manuscripts/BNF" "manuscripts/Pistoia" "" >"${BATS_TEST_TMPDIR}/in.txt"
  run bash "$SCRIPT" --shards "${BATS_TEST_TMPDIR}/in.txt" --root "$root" --missing-only
  [ "$status" -eq 0 ]
  [ "$output" = "manuscripts/Pistoia" ]
}

@test "without missing-only keeps existing paths" {
  root="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$root/corpora"
  printf '%s\n' "corpora" >"${BATS_TEST_TMPDIR}/in.txt"
  run bash "$SCRIPT" --shards "${BATS_TEST_TMPDIR}/in.txt" --root "$root"
  [ "$status" -eq 0 ]
  [ "$output" = "corpora" ]
}

@test "empty selection fails" {
  root="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$root/corpora"
  printf '%s\n' "corpora" >"${BATS_TEST_TMPDIR}/in.txt"
  run bash "$SCRIPT" --shards "${BATS_TEST_TMPDIR}/in.txt" --root "$root" --missing-only
  [ "$status" -eq 1 ]
}

@test "requires --shards" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}
