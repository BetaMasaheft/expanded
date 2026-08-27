#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/ci/check-makeExpand-output.sh"

@test "accepts expanded N with N>=1" {
  run bash "$SCRIPT" "expanded 3 file(s) under /db/apps/expanded/corpora"
  [ "$status" -eq 0 ]
}

@test "rejects expanded 0" {
  run bash "$SCRIPT" "expanded 0 file(s) under /db/apps/expanded/corpora"
  [ "$status" -ne 0 ]
}

@test "rejects bare expanded 0" {
  run bash "$SCRIPT" "expanded 0"
  [ "$status" -ne 0 ]
}

@test "rejects expanded 00" {
  run bash "$SCRIPT" "expanded 00 file(s) under /db/apps/expanded/corpora"
  [ "$status" -ne 0 ]
}

@test "rejects garbage" {
  run bash "$SCRIPT" "ok"
  [ "$status" -ne 0 ]
}

@test "reads body from stdin" {
  run bash -c "printf '%s' 'expanded 1 file(s) under /x' | bash \"$SCRIPT\""
  [ "$status" -eq 0 ]
}
