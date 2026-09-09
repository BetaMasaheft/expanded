#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/ci/check-retired-ids.sh"

@test "passes when no retired basename is present" {
  root="${BATS_TEST_TMPDIR}/clean"
  mkdir -p "${root}/works/1-1000" "${root}/config"
  printf '%s\n' 'RETIREDstub' > "${root}/config/retired-ids.txt"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="live"/>' \
    > "${root}/works/1-1000/LIVEok.xml"
  run bash "$SCRIPT" --root "$root"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:"* ]]
}

@test "fails when a retired basename is present" {
  root="${BATS_TEST_TMPDIR}/hit"
  mkdir -p "${root}/persons/1-1000" "${root}/config"
  printf '%s\n' '# comment' 'PRS9999Ghost' 'OTHER' > "${root}/config/retired-ids.txt"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="PRS9999Ghost"/>' \
    > "${root}/persons/1-1000/PRS9999Ghost.xml"
  run bash "$SCRIPT" --root "$root"
  [ "$status" -ne 0 ]
  [[ "$output" == *"PRS9999Ghost"* ]] || [[ "$stderr" == *"PRS9999Ghost"* ]]
}

@test "ignores optional continuesAs column" {
  root="${BATS_TEST_TMPDIR}/cont"
  mkdir -p "${root}/manuscripts/X" "${root}/config"
  printf '%s\n' 'MM001	EMDA58' > "${root}/config/retired-ids.txt"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="EMDA58"/>' \
    > "${root}/manuscripts/X/EMDA58.xml"
  run bash "$SCRIPT" --root "$root"
  [ "$status" -eq 0 ]
}

@test "repo config/retired-ids.txt is currently clean" {
  run bash "$SCRIPT" --root "${BATS_TEST_DIRNAME}/.."
  [ "$status" -eq 0 ]
}
