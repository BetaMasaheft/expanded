#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/ci/stage-shard-export.sh"
FIX="${BATS_TEST_DIRNAME}/fixtures/stage"

@test "stages xst leaf under artifact-root/rel" {
  art="${BATS_TEST_TMPDIR}/shard-out"
  run bash "$SCRIPT" \
    --rel corpora \
    --export-root "${FIX}/export" \
    --artifact-root "$art"
  [ "$status" -eq 0 ]
  [ -f "${art}/corpora/doc.xml" ]
  [ ! -f "${art}/corpora/__contents__.xml" ]
  [ -f "${art}/.shard-manifest" ]
}

@test "refuses zero xml export" {
  art="${BATS_TEST_TMPDIR}/empty-out"
  run bash "$SCRIPT" \
    --rel corpora \
    --export-root "${FIX}/export-empty" \
    --artifact-root "$art"
  [ "$status" -ne 0 ]
  [ ! -d "${art}/corpora" ]
  [ ! -f "${art}/.shard-manifest" ]
}

@test "strips leading ./ on rel" {
  art="${BATS_TEST_TMPDIR}/dot-out"
  run bash "$SCRIPT" \
    --rel ./corpora \
    --export-root "${FIX}/export" \
    --artifact-root "$art"
  [ "$status" -eq 0 ]
  [ -f "${art}/corpora/doc.xml" ]
}

@test "refuses missing leaf" {
  art="${BATS_TEST_TMPDIR}/missing-out"
  run bash "$SCRIPT" \
    --rel works/1-1000 \
    --export-root "${FIX}/export" \
    --artifact-root "$art"
  [ "$status" -ne 0 ]
}
