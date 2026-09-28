#!/usr/bin/env bash
# Append issued-id rows for deleted.xml ids missing from retired-ids.xml.
# xmllint + bash (no Python). Dry-run by default; pass --write to rewrite.
set -euo pipefail

deleted=""
retired=""
write=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --deleted) deleted=$2; shift 2 ;;
    --retired) retired=$2; shift 2 ;;
    --write) write=1; shift ;;
    -h|--help)
      echo "Usage: $0 --deleted FILE --retired FILE [--write]" >&2
      exit 0
      ;;
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

infer_type() {
  case "$1" in
    LIT*) echo works ;;
    PRS*) echo persons ;;
    LOC*) echo places ;;
    INS*) echo institutions ;;
    NAR*) echo narratives ;;
    AUTH*) echo authority-files ;;
    *) echo manuscripts ;;
  esac
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# id → change (empty if none); XPath skips comment nodes
count=$(xmllint --xpath 'count(//*[local-name()="item"])' "$deleted" 2>/dev/null || echo 0)
count=${count%.*}
: >"$tmp/deleted.tsv"
i=1
while [ "$i" -le "$count" ]; do
  id=$(xmllint --xpath "normalize-space(string((//*[local-name()=\"item\"])[$i]))" "$deleted")
  change=$(xmllint --xpath "string((//*[local-name()=\"item\"])[$i]/@change)" "$deleted" 2>/dev/null || true)
  id=$(nfc_line "$id")
  id=${id%"${id##*[![:space:]]}"}
  if [ -n "$id" ]; then
    printf '%s\t%s\n' "$id" "$change" >>"$tmp/deleted.tsv"
  fi
  i=$((i + 1))
done

sort -u -t $'\t' -k1,1 "$tmp/deleted.tsv" >"$tmp/deleted.sorted.tsv"
cut -f1 "$tmp/deleted.sorted.tsv" | sort -u >"$tmp/deleted.ids"

xmllint --xpath '//*[local-name()="issued-id"]/@id' "$retired" 2>/dev/null \
  | sed -e 's/^ *id="//g' -e 's/"$//' \
  | while IFS= read -r line || [ -n "$line" ]; do
      line=${line#"${line%%[![:space:]]*}"}
      line=${line%"${line##*[![:space:]]}"}
      [ -n "$line" ] || continue
      nfc_line "$line"
    done | sort -u >"$tmp/retired.ids"

comm -23 "$tmp/deleted.ids" "$tmp/retired.ids" >"$tmp/missing.ids"
comm -13 "$tmp/deleted.ids" "$tmp/retired.ids" >"$tmp/retired_only.ids"

deleted_n=$(wc -l <"$tmp/deleted.ids" | tr -d ' ')
retired_n=$(wc -l <"$tmp/retired.ids" | tr -d ' ')
missing_n=$(wc -l <"$tmp/missing.ids" | tr -d ' ')
retired_only_n=$(wc -l <"$tmp/retired_only.ids" | tr -d ' ')

echo "deleted unique: ${deleted_n}"
echo "retired: ${retired_n}"
echo "to append: ${missing_n}"
echo "retired-only (triage): ${retired_only_n}"

if [ "$write" -eq 0 ]; then
  head -n 20 "$tmp/missing.ids" | sed 's/^/  would add /'
  if [ "$missing_n" -gt 20 ]; then
    echo "  ... $((missing_n - 20)) more"
  fi
  exit 0
fi

: >"$tmp/append.xml"
while IFS= read -r id || [ -n "$id" ]; do
  [ -n "$id" ] || continue
  change=$(awk -F '\t' -v id="$id" '$1 == id { print $2; exit }' "$tmp/deleted.sorted.tsv")
  typ=$(infer_type "$id")
  retired_at=""
  if [ -n "$change" ]; then
    retired_at=${change%%T*}
    case "$retired_at" in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
      *) retired_at="" ;;
    esac
  fi
  if [ -n "$retired_at" ]; then
    printf '<issued-id id="%s" type="%s" mode="manual" state="retired" reason="deleted" source="lists/deleted.xml" retiredAt="%s"/>\n' \
      "$id" "$typ" "$retired_at" >>"$tmp/append.xml"
  else
    printf '<issued-id id="%s" type="%s" mode="manual" state="retired" reason="deleted" source="lists/deleted.xml"/>\n' \
      "$id" "$typ" >>"$tmp/append.xml"
  fi
done <"$tmp/missing.ids"

# Insert new rows before the closing </retired-ids> (default-ns elements).
awk -v append_file="$tmp/append.xml" '
  /<\/retired-ids>/ {
    while ((getline line < append_file) > 0) print "  " line
    close(append_file)
  }
  { print }
' "$retired" >"$tmp/retired.new.xml"

mv "$tmp/retired.new.xml" "$retired"
echo "wrote ${retired}"
