#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/ci/prune-absent-shards.sh"

setup() {
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p \
    "${REPO}/manuscripts/Berlin" \
    "${REPO}/manuscripts/Gone" \
    "${REPO}/works/new" \
    "${REPO}/authority-files/new"
  echo '<TEI/>' > "${REPO}/manuscripts/Berlin/Ber.xml"
  echo '<TEI/>' > "${REPO}/manuscripts/Gone/Gone.xml"
  echo '<TEI/>' > "${REPO}/works/new/STUB.xml"
  echo '<TEI/>' > "${REPO}/authority-files/new/orphan.xml"
  printf '%s\n' 'manuscripts/Gone' > "${BATS_TEST_TMPDIR}/removed.txt"
}

@test "deletes only the paths the image named" {
  run bash "$SCRIPT" --paths "${BATS_TEST_TMPDIR}/removed.txt" --root "$REPO"
  [ "$status" -eq 0 ]
  [ ! -d "${REPO}/manuscripts/Gone" ]
  [ -f "${REPO}/manuscripts/Berlin/Ber.xml" ]
  [ -f "${REPO}/works/new/STUB.xml" ]
  [ -f "${REPO}/authority-files/new/orphan.xml" ]
}

@test "empty list deletes nothing" {
  : > "${BATS_TEST_TMPDIR}/none.txt"
  run bash "$SCRIPT" --paths "${BATS_TEST_TMPDIR}/none.txt" --root "$REPO"
  [ "$status" -eq 0 ]
  [ -d "${REPO}/manuscripts/Gone" ]
}

@test "refuses a reservation path and deletes nothing" {
  printf '%s\n' 'manuscripts/Gone' 'works/new' > "${BATS_TEST_TMPDIR}/bad.txt"
  run bash "$SCRIPT" --paths "${BATS_TEST_TMPDIR}/bad.txt" --root "$REPO"
  [ "$status" -eq 1 ]
  [ -d "${REPO}/manuscripts/Gone" ]
  [ -f "${REPO}/works/new/STUB.xml" ]
}

@test "refuses a reservation path with a trailing slash" {
  printf '%s\n' 'works/new/' > "${BATS_TEST_TMPDIR}/trailing.txt"
  run bash "$SCRIPT" --paths "${BATS_TEST_TMPDIR}/trailing.txt" --root "$REPO"
  [ "$status" -eq 1 ]
  [ -f "${REPO}/works/new/STUB.xml" ]
}

@test "requires --paths and --root" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}
