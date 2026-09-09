#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/ci/check-retired-ids.sh"

write_manifest() {
  local path=$1
  shift
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<retired-ids xmlns="https://betamasaheft.eu/betmas-id-manager">'
    for spec in "$@"; do
      # spec: id|continuesAs (continuesAs optional)
      id=${spec%%|*}
      cont=${spec#*|}
      if [ "$cont" = "$spec" ] || [ -z "$cont" ]; then
        echo "  <issued-id id=\"${id}\" type=\"works\" mode=\"auto\" state=\"retired\"/>"
      else
        echo "  <issued-id id=\"${id}\" type=\"manuscripts\" mode=\"manual\" state=\"retired\" continuesAs=\"${cont}\"/>"
      fi
    done
    echo '</retired-ids>'
  } > "$path"
}

@test "passes when no retired basename is present" {
  root="${BATS_TEST_TMPDIR}/clean"
  mkdir -p "${root}/works/1-1000" "${root}/config"
  write_manifest "${root}/config/retired-ids.xml" "RETIREDstub"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="live"/>' \
    > "${root}/works/1-1000/LIVEok.xml"
  run bash "$SCRIPT" --root "$root"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:"* ]]
}

@test "fails when a retired basename is present" {
  root="${BATS_TEST_TMPDIR}/hit"
  mkdir -p "${root}/persons/1-1000" "${root}/config"
  write_manifest "${root}/config/retired-ids.xml" "PRS9999Ghost" "OTHER"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="PRS9999Ghost"/>' \
    > "${root}/persons/1-1000/PRS9999Ghost.xml"
  run bash "$SCRIPT" --root "$root"
  [ "$status" -ne 0 ]
  [[ "$output" == *"PRS9999Ghost"* ]] || [[ "$stderr" == *"PRS9999Ghost"* ]]
}

@test "ignores optional continuesAs on issued-id" {
  root="${BATS_TEST_TMPDIR}/cont"
  mkdir -p "${root}/manuscripts/X" "${root}/config"
  write_manifest "${root}/config/retired-ids.xml" "MM001|EMDA58"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="EMDA58"/>' \
    > "${root}/manuscripts/X/EMDA58.xml"
  run bash "$SCRIPT" --root "$root"
  [ "$status" -eq 0 ]
}

@test "fails when a retired basename is under corpus/new" {
  root="${BATS_TEST_TMPDIR}/new-hit"
  mkdir -p "${root}/works/new" "${root}/config"
  write_manifest "${root}/config/retired-ids.xml" "LIT9999Ghost"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="LIT9999Ghost"/>' \
    > "${root}/works/new/LIT9999Ghost.xml"
  run bash "$SCRIPT" --root "$root"
  [ "$status" -ne 0 ]
  [[ "$output" == *"LIT9999Ghost"* ]] || [[ "$stderr" == *"LIT9999Ghost"* ]]
}

@test "matches URL-encoded tombstone against UTF-8 basename" {
  root="${BATS_TEST_TMPDIR}/encoded"
  mkdir -p "${root}/persons/1-1000" "${root}/config"
  write_manifest "${root}/config/retired-ids.xml" "PRS14070%E1%B8%A4abtaMG"
  # filesystem basename uses the decoded character, not %XX
  decoded=$(printf '%b' 'PRS14070\xE1\xB8\xA4abtaMG')
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0"/>' \
    > "${root}/persons/1-1000/${decoded}.xml"
  run bash "$SCRIPT" --root "$root"
  [ "$status" -ne 0 ]
}

@test "does not treat parentId as issued-id @id" {
  root="${BATS_TEST_TMPDIR}/parentid"
  mkdir -p "${root}/works/1-1000" "${root}/config"
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<retired-ids xmlns="https://betamasaheft.eu/betmas-id-manager">'
    echo '  <issued-id id="REALRETIRED" parentId="NOTANID" type="works" mode="auto" state="retired"/>'
    echo '</retired-ids>'
  } > "${root}/config/retired-ids.xml"
  echo '<TEI xmlns="http://www.tei-c.org/ns/1.0"/>' \
    > "${root}/works/1-1000/NOTANID.xml"
  run bash "$SCRIPT" --root "$root"
  [ "$status" -eq 0 ]
}

@test "repo config/retired-ids.xml is currently clean" {
  run bash "$SCRIPT" --root "${BATS_TEST_DIRNAME}/.."
  [ "$status" -eq 0 ]
}
