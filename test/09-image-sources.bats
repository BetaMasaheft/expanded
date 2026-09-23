#!/usr/bin/env bats

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/ci/image-sources.sh"

@test "maps narrative onto narratives and lifts bibliography" {
  cat >"${BATS_TEST_TMPDIR}/labels.json" <<'EOF'
{
  "eu.betamasaheft.ref.betmasweb": "web",
  "eu.betamasaheft.ref.bibliography": "bib",
  "eu.betamasaheft.ref.narrative": "nar",
  "eu.betamasaheft.ref.manuscripts": "mss",
  "eu.betamasaheft.ref.works": "w",
  "eu.betamasaheft.ref.traces": "ignored"
}
EOF
  run bash "$SCRIPT" --labels "${BATS_TEST_TMPDIR}/labels.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.version == 1' >/dev/null
  echo "$output" | jq -e '.betmasweb == "web"' >/dev/null
  echo "$output" | jq -e '.bibliography == "bib"' >/dev/null
  echo "$output" | jq -e '.corpora.narratives == "nar"' >/dev/null
  echo "$output" | jq -e '.corpora.manuscripts == "mss"' >/dev/null
  echo "$output" | jq -e '.corpora.works == "w"' >/dev/null
  echo "$output" | jq -e 'has("traces") | not' >/dev/null
}

@test "missing labels are empty strings" {
  echo '{}' >"${BATS_TEST_TMPDIR}/labels.json"
  run bash "$SCRIPT" --labels "${BATS_TEST_TMPDIR}/labels.json"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.betmasweb == "" and .corpora.narratives == ""' >/dev/null
}
