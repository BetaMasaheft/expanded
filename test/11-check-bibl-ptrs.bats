#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/ci/check-bibl-ptrs.sh"
FIX="${BATS_TEST_DIRNAME}/../scripts/ci/fixtures/mini-bibl"

@test "passes when ptrs are in citations or exceptions" {
  root="${BATS_TEST_TMPDIR}/ok"
  mkdir -p "${root}/works"
  cp "${FIX}/tei-ok.xml" "${root}/works/ok.xml"
  run bash "$SCRIPT" \
    --root "${root}" \
    --citations "${FIX}/citations.xml" \
    --exceptions "${FIX}/bibl-exceptions.xml"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bm: ptr coverage OK"* ]]
}

@test "fails when a ptr is missing from citations and exceptions" {
  root="${BATS_TEST_TMPDIR}/miss"
  mkdir -p "${root}/works"
  cp "${FIX}/tei-missing.xml" "${root}/works/miss.xml"
  run bash "$SCRIPT" \
    --root "${root}" \
    --citations "${FIX}/citations.xml" \
    --exceptions "${FIX}/bibl-exceptions.xml"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISSING bm: ptr: bm:NotInCitationsOrExc"* ]] \
    || [[ "$stderr" == *"MISSING bm: ptr: bm:NotInCitationsOrExc"* ]]
}

@test "fails closed when scan finds no bm: ptrs" {
  root="${BATS_TEST_TMPDIR}/empty"
  mkdir -p "${root}/works"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0"><p>no ptr</p></TEI>' \
    >"${root}/works/bare.xml"
  run bash "$SCRIPT" \
    --root "${root}" \
    --citations "${FIX}/citations.xml" \
    --exceptions "${FIX}/bibl-exceptions.xml"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no bm: ptrs"* ]] || [[ "$stderr" == *"no bm: ptrs"* ]]
}
