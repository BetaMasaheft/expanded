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

@test "repo config/retired-ids.xml is currently clean" {
  run bash "$SCRIPT" --root "${BATS_TEST_DIRNAME}/.."
  [ "$status" -eq 0 ]
}
