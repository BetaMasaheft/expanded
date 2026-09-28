#!/usr/bin/env bash
# HP5: every uncommented deleted.xml item text must appear as issued-id/@id
# in retired-ids.xml, or in an optional exceptions file.
# Uses xmllint (libxml2) + comm — same stack as check-retired-ids / validate_*.
# XML comments are invisible to XPath, so commented-out <item>s are excluded.
# Ids are read one node at a time via indexed string((… )[$i]) so libxml2 cannot
# coerce a multi-node text() node-set into a single concatenated string.
# Optional NFC via uconv(1) when present; otherwise identity (IDs are ASCII BM forms).
set -euo pipefail

deleted=""
retired=""
exceptions=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --deleted) deleted=$2; shift 2 ;;
    --retired) retired=$2; shift 2 ;;
    --exceptions) exceptions=$2; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

: "${deleted:?--deleted required}"
: "${retired:?--retired required}"

if ! command -v xmllint >/dev/null 2>&1; then
  echo "xmllint is required (libxml2-utils)" >&2
  exit 2
fi

for path in "$deleted" "$retired"; do
  if [ ! -f "$path" ]; then
    echo "HP5 FAIL: missing file: ${path}" >&2
    exit 2
  fi
done

if [ -n "$exceptions" ] && [ ! -f "$exceptions" ]; then
  echo "HP5 FAIL: exceptions file not found: ${exceptions}" >&2
  exit 2
fi

nfc_line() {
  if command -v uconv >/dev/null 2>&1; then
    printf '%s\n' "$1" | uconv -f utf-8 -t utf-8 -x any-nfc
  else
    printf '%s\n' "$1"
  fi
}

trim() {
  local s=$1
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  printf '%s' "$s"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Fail closed: xmllint non-zero aborts (set -e). Indexed string() avoids text() merge.
deleted_count=$(xmllint --xpath 'count(//*[local-name()="item"])' "$deleted")
deleted_count=${deleted_count%.*}
: >"$tmp/deleted.raw"
i=1
while [ "$i" -le "$deleted_count" ]; do
  id=$(xmllint --xpath "normalize-space(string((//*[local-name()=\"item\"])[$i]))" "$deleted")
  id=$(trim "$(nfc_line "$id")")
  if [ -n "$id" ]; then
    printf '%s\n' "$id" >>"$tmp/deleted.raw"
  fi
  i=$((i + 1))
done
sort -u "$tmp/deleted.raw" >"$tmp/deleted.ids"

retired_count=$(xmllint --xpath 'count(//*[local-name()="issued-id"])' "$retired")
retired_count=${retired_count%.*}
: >"$tmp/retired.raw"
i=1
while [ "$i" -le "$retired_count" ]; do
  id=$(xmllint --xpath "normalize-space(string((//*[local-name()=\"issued-id\"])[$i]/@id))" "$retired")
  id=$(trim "$(nfc_line "$id")")
  if [ -n "$id" ]; then
    printf '%s\n' "$id" >>"$tmp/retired.raw"
  fi
  i=$((i + 1))
done
sort -u "$tmp/retired.raw" >"$tmp/retired.ids"

: >"$tmp/exceptions.raw"
if [ -n "$exceptions" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|\#*) continue ;;
    esac
    line=$(trim "$line")
    case "$line" in
      \#*) continue ;;
    esac
    [ -n "$line" ] || continue
    printf '%s\n' "$(trim "$(nfc_line "$line")")" >>"$tmp/exceptions.raw"
  done <"$exceptions"
fi
sort -u "$tmp/exceptions.raw" >"$tmp/exceptions.ids"

sort -u "$tmp/retired.ids" "$tmp/exceptions.ids" >"$tmp/allowed.ids"

missing=$tmp/missing.ids
comm -23 "$tmp/deleted.ids" "$tmp/allowed.ids" >"$missing"

deleted_n=$(wc -l <"$tmp/deleted.ids" | tr -d ' ')
retired_n=$(wc -l <"$tmp/retired.ids" | tr -d ' ')
exc_n=$(wc -l <"$tmp/exceptions.ids" | tr -d ' ')
missing_n=$(wc -l <"$missing" | tr -d ' ')

if [ "$missing_n" -gt 0 ]; then
  echo "HP5 FAIL: ${missing_n} deleted id(s) not in retired-ids or exceptions:" >&2
  sed 's/^/  /' "$missing" >&2
  exit 1
fi

echo "OK: ${deleted_n} deleted ids ⊆ ${retired_n} retired ids (+${exc_n} exceptions)"
