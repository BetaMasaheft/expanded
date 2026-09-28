#!/usr/bin/env bash
# HP5: every uncommented deleted.xml item text must appear as issued-id/@id
# in retired-ids.xml, or in an optional exceptions file.
# Uses xmllint (libxml2) + comm — same stack as check-retired-ids / validate_*.
# XML comments are invisible to XPath, so commented-out <item>s are excluded.
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

nfc_line() {
  if command -v uconv >/dev/null 2>&1; then
    printf '%s\n' "$1" | uconv -f utf-8 -t utf-8 -x any-nfc
  else
    printf '%s\n' "$1"
  fi
}

normalize_ids() {
  # stdin: raw lines → stdout: NFC-trimmed, non-empty, sorted unique
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}
    [ -n "$line" ] || continue
    nfc_line "$line"
  done | sort -u
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# item/text() — one id per line for the mini fixtures and deleted snapshot
xmllint --xpath '//*[local-name()="item"]/text()' "$deleted" 2>/dev/null \
  | normalize_ids >"$tmp/deleted.ids" || true

xmllint --xpath '//*[local-name()="issued-id"]/@id' "$retired" 2>/dev/null \
  | sed -e 's/^ *id="//g' -e 's/"$//g' \
  | normalize_ids >"$tmp/retired.ids" || true

: >"$tmp/exceptions.ids"
if [ -n "$exceptions" ] && [ -f "$exceptions" ]; then
  grep -v '^[[:space:]]*#' "$exceptions" | grep -v '^[[:space:]]*$' \
    | normalize_ids >"$tmp/exceptions.ids" || true
fi

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
