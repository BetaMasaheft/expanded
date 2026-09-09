#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/ci/report-overdue-new-stubs.sh"

@test "OK when stubs have no landed twin" {
  root="${BATS_TEST_TMPDIR}/clean"
  mkdir -p "${root}/persons/new" "${root}/persons/PRS1-1000"
  echo '<TEI xml:id="PRS0001Stub"/>' > "${root}/persons/new/PRS0001Stub.xml"
  echo '<TEI xml:id="PRS0002Live"/>' > "${root}/persons/PRS1-1000/PRS0002Live.xml"
  run bash "$SCRIPT" --root "$root"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:"* ]]
}

@test "warns (exit 0) when stub basename also landed in expanded" {
  root="${BATS_TEST_TMPDIR}/overdue"
  mkdir -p "${root}/works/new" "${root}/works/1-1000"
  echo '<TEI xml:id="LIT0001Landed"/>' > "${root}/works/new/LIT0001Landed.xml"
  echo '<TEI xml:id="LIT0001Landed"/>' > "${root}/works/1-1000/LIT0001Landed.xml"
  run bash "$SCRIPT" --root "$root"
  [ "$status" -eq 0 ]
  [[ "$output" == *"LIT0001Landed"* ]] || [[ "$stderr" == *"LIT0001Landed"* ]]
}

@test "strict fails when overdue stubs exist" {
  root="${BATS_TEST_TMPDIR}/strict"
  mkdir -p "${root}/works/new" "${root}/works/1-1000"
  echo '<TEI xml:id="LIT0001Landed"/>' > "${root}/works/new/LIT0001Landed.xml"
  echo '<TEI xml:id="LIT0001Landed"/>' > "${root}/works/1-1000/LIT0001Landed.xml"
  run bash "$SCRIPT" --root "$root" --strict
  [ "$status" -ne 0 ]
}

@test "betmas-data marks stub overdue even if expanded has no twin" {
  root="${BATS_TEST_TMPDIR}/exp"
  data="${BATS_TEST_TMPDIR}/data"
  mkdir -p "${root}/persons/new" "${data}/persons/PRS1-1000"
  echo '<TEI xml:id="PRS0099Landed"/>' > "${root}/persons/new/PRS0099Landed.xml"
  echo '<TEI xml:id="PRS0099Landed"/>' > "${data}/persons/PRS1-1000/PRS0099Landed.xml"
  run bash "$SCRIPT" --root "$root"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:"* ]]
  run bash "$SCRIPT" --root "$root" --betmas-data "$data"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PRS0099Landed"* ]] || [[ "$stderr" == *"PRS0099Landed"* ]]
}

@test "repo has no expanded-only overdue stubs right now" {
  run bash "$SCRIPT" --root "${BATS_TEST_DIRNAME}/.."
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:"* ]]
}
