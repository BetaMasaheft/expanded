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

@test "corpus merge preserves git orphans absent from export" {
  REPO="${BATS_TEST_TMPDIR}/repo-iha"
  mkdir -p "${REPO}/works/IHA/works" "${REPO}/works/1-1000/works"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="keep"/> ' \
    > "${REPO}/works/IHA/works/LIT0001IHA.xml"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="old"/> ' \
    > "${REPO}/works/1-1000/works/old.xml"
  shards="${BATS_TEST_TMPDIR}/shards-works"
  mkdir -p "${shards}/works/1-1000/works"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="new"/> ' \
    > "${shards}/works/1-1000/works/new.xml"
  printf '%s\n' 'works' > "${BATS_TEST_TMPDIR}/works-corpus.txt"
  run bash "$SCRIPT" \
    --manifest "${BATS_TEST_TMPDIR}/works-corpus.txt" \
    --shards-in "$shards" \
    --repo-root "$REPO"
  [ "$status" -eq 0 ]
  [ -f "${REPO}/works/IHA/works/LIT0001IHA.xml" ]
  [ -f "${REPO}/works/1-1000/works/new.xml" ]
  [ ! -f "${REPO}/works/1-1000/works/old.xml" ]
}

@test "corpus merge preserves authority-files/new orphan" {
  REPO="${BATS_TEST_TMPDIR}/repo-auth-new"
  mkdir -p "${REPO}/authority-files/new/authority-files" \
    "${REPO}/authority-files/ArtThemes/authority-files"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="orphan"/> ' \
    > "${REPO}/authority-files/new/authority-files/orphan.xml"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="old"/> ' \
    > "${REPO}/authority-files/ArtThemes/authority-files/old.xml"
  shards="${BATS_TEST_TMPDIR}/shards-auth"
  mkdir -p "${shards}/authority-files/ArtThemes/authority-files"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="fresh"/> ' \
    > "${shards}/authority-files/ArtThemes/authority-files/fresh.xml"
  printf '%s\n' 'authority-files' > "${BATS_TEST_TMPDIR}/auth-corpus.txt"
  run bash "$SCRIPT" \
    --manifest "${BATS_TEST_TMPDIR}/auth-corpus.txt" \
    --shards-in "$shards" \
    --repo-root "$REPO"
  [ "$status" -eq 0 ]
  [ -f "${REPO}/authority-files/new/authority-files/orphan.xml" ]
  [ -f "${REPO}/authority-files/ArtThemes/authority-files/fresh.xml" ]
  [ ! -f "${REPO}/authority-files/ArtThemes/authority-files/old.xml" ]
}

@test "allow-partial merges present shards and skips missing" {
  printf '%s\n' 'corpora' 'missing' > "${BATS_TEST_TMPDIR}/partial.txt"
  shards="${BATS_TEST_TMPDIR}/shards-partial"
  mkdir -p "${shards}/corpora"
  cp -a "${FIX}/shards-in/corpora/." "${shards}/corpora/"
  run bash "$SCRIPT" \
    --manifest "${BATS_TEST_TMPDIR}/partial.txt" \
    --shards-in "$shards" \
    --repo-root "$REPO" \
    --allow-partial
  [ "$status" -eq 0 ]
  [ -f "${REPO}/corpora/new.xml" ]
  [ ! -f "${REPO}/corpora/old.xml" ]
}

@test "corpus merge updates new/ without wiping expanded-only stubs" {
  REPO="${BATS_TEST_TMPDIR}/repo-new-protect"
  mkdir -p "${REPO}/works/new" "${REPO}/works/1-1000"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="stub"/>' \
    > "${REPO}/works/new/STUBkeep.xml"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="old"/>' \
    > "${REPO}/works/1-1000/old.xml"
  shards="${BATS_TEST_TMPDIR}/shards-works-new"
  mkdir -p "${shards}/works/new" "${shards}/works/1-1000"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="exportstub"/>' \
    > "${shards}/works/new/EXPORTONLY.xml"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="fresh"/>' \
    > "${shards}/works/1-1000/fresh.xml"
  printf '%s\n' 'works' > "${BATS_TEST_TMPDIR}/works-new.txt"
  run bash "$SCRIPT" \
    --manifest "${BATS_TEST_TMPDIR}/works-new.txt" \
    --shards-in "$shards" \
    --repo-root "$REPO"
  [ "$status" -eq 0 ]
  [ -f "${REPO}/works/new/STUBkeep.xml" ]
  [ -f "${REPO}/works/new/EXPORTONLY.xml" ]
  [ -f "${REPO}/works/1-1000/fresh.xml" ]
  [ ! -f "${REPO}/works/1-1000/old.xml" ]
}

@test "merges */new reservation shard without --delete" {
  REPO="${BATS_TEST_TMPDIR}/repo-new-shard"
  mkdir -p "${REPO}/works/new"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="stub"/>' \
    > "${REPO}/works/new/STUBkeep.xml"
  shards="${BATS_TEST_TMPDIR}/shards-new-only"
  mkdir -p "${shards}/works/new"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="fromexport"/>' \
    > "${shards}/works/new/FROMEXPORT.xml"
  printf '%s\n' 'works/new' > "${BATS_TEST_TMPDIR}/new-shard.txt"
  run bash "$SCRIPT" \
    --manifest "${BATS_TEST_TMPDIR}/new-shard.txt" \
    --shards-in "$shards" \
    --repo-root "$REPO"
  [ "$status" -eq 0 ]
  [ -f "${REPO}/works/new/STUBkeep.xml" ]
  [ -f "${REPO}/works/new/FROMEXPORT.xml" ]
}

@test "reservation merge drops overdue stub when canonical exists outside new/" {
  REPO="${BATS_TEST_TMPDIR}/repo-overdue"
  mkdir -p "${REPO}/works/new" "${REPO}/works/1-1000"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="overdue"/>' \
    > "${REPO}/works/new/OVERDUE.xml"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="landed"/>' \
    > "${REPO}/works/1-1000/OVERDUE.xml"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="wip"/>' \
    > "${REPO}/works/new/WIPONLY.xml"
  shards="${BATS_TEST_TMPDIR}/shards-overdue"
  mkdir -p "${shards}/works/new"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="freshstub"/>' \
    > "${shards}/works/new/FRESH.xml"
  printf '%s\n' 'works/new' > "${BATS_TEST_TMPDIR}/overdue.txt"
  run bash "$SCRIPT" \
    --manifest "${BATS_TEST_TMPDIR}/overdue.txt" \
    --shards-in "$shards" \
    --repo-root "$REPO"
  [ "$status" -eq 0 ]
  [ ! -f "${REPO}/works/new/OVERDUE.xml" ]
  [ -f "${REPO}/works/new/WIPONLY.xml" ]
  [ -f "${REPO}/works/new/FRESH.xml" ]
  [ -f "${REPO}/works/1-1000/OVERDUE.xml" ]
}
