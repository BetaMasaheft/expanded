#!/usr/bin/env bash
# Fail if any retired @id from config/retired-ids.xml is present as a
# *.xml basename or root TEI @xml:id in the expanded tree (blocks
# re-expand / assemble resurrection). Manifest shape mirrors
# betmas-id-manager bim:issued-id. Nested xml:id values are ignored.
# Compares NFC-normalized forms; URL-decodes manifest ids. Requires
# xmllint; uses python3 for NFC when available. Bash 3.2+ compatible.
set -euo pipefail

root=.
manifest=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --root" >&2
        exit 2
      fi
      root=$2
      shift 2
      ;;
    --manifest)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --manifest" >&2
        exit 2
      fi
      manifest=$2
      shift 2
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
    *)
      echo "Unexpected argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "${manifest}" ]; then
  manifest="${root}/config/retired-ids.xml"
fi

if [ ! -f "${manifest}" ]; then
  echo "Missing retired-ids manifest: ${manifest}" >&2
  exit 1
fi

if ! command -v xmllint >/dev/null 2>&1; then
  echo "xmllint is required to read ${manifest}" >&2
  exit 2
fi

ids_tmp=$(mktemp)
basename_tmp=$(mktemp)
xmlid_tmp=$(mktemp)
files_tmp=$(mktemp)
trap 'rm -f "${ids_tmp}" "${basename_tmp}" "${xmlid_tmp}" "${files_tmp}"' EXIT

# Percent-decode so tombstones stored as URL-encoded match UTF-8 forms.
urldecode() {
  # shellcheck disable=SC2059
  printf '%b' "${1//%/\\x}"
}

# NFC normalize one line (identity if python3 unavailable).
nfc_line() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, unicodedata; print(unicodedata.normalize("NFC", sys.argv[1]))' "$1"
  else
    printf '%s\n' "$1"
  fi
}

nfc_file() {
  local src=$1 dest=$2
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import sys, unicodedata
with open(sys.argv[1], encoding="utf-8") as f, open(sys.argv[2], "w", encoding="utf-8") as out:
    for line in f:
        out.write(unicodedata.normalize("NFC", line.rstrip("\n")) + "\n")
' "${src}" "${dest}"
  else
    cp "${src}" "${dest}"
  fi
}

# issued-id/@id via xmllint (local-name ignores default namespace).
xmllint --xpath '//*[local-name()="issued-id"]/@id' "${manifest}" 2>/dev/null |
  grep -oE 'id="[^"]+"' |
  sed 's/^id="//; s/"$//' |
  while IFS= read -r id || [ -n "${id}" ]; do
    [ -z "${id}" ] && continue
    printf '%s\n' "${id}"
    decoded=$(urldecode "${id}")
    if [ "${decoded}" != "${id}" ]; then
      printf '%s\n' "${decoded}"
    fi
  done |
  sort -u > "${ids_tmp}.raw"
nfc_file "${ids_tmp}.raw" "${ids_tmp}"
rm -f "${ids_tmp}.raw"

if [ ! -s "${ids_tmp}" ]; then
  echo "retired-ids manifest has no issued-id/@id: ${manifest}" >&2
  exit 1
fi

# Corpus XML under root (exclude test fixtures / build / .git / config).
find "${root}" \
  \( -path "${root}/test" -o -path "${root}/.git" -o -path "${root}/build" -o -path "${root}/config" \) -prune \
  -o -type f -name '*.xml' -print > "${files_tmp}"

# Fast path: one Python walk for basenames + root TEI @xml:id (NFC).
# Falls back to sequential xmllint if python3 is missing.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${files_tmp}" "${basename_tmp}" "${xmlid_tmp}" <<'PY'
import re
import sys
import unicodedata

files_path, basename_out, xmlid_out = sys.argv[1:4]
# Root start-tag only; ignore nested xml:id.
root_tei = re.compile(
    br"<\s*(?:[\w.-]+:)?TEI\b[^>]*?\bxml:id\s*=\s*[\"']([^\"']+)[\"']",
    re.I | re.S,
)

basenames = set()
xmlids = set()
with open(files_path, encoding="utf-8") as fh:
    for line in fh:
        path = line.rstrip("\n")
        if not path:
            continue
        base = path.rsplit("/", 1)[-1]
        if base.endswith(".xml"):
            base = base[:-4]
        basenames.add(unicodedata.normalize("NFC", base))
        try:
            with open(path, "rb") as xf:
                head = xf.read(8192)
        except OSError:
            continue
        # Strip XML declaration / comments / PI before root for a cheap match.
        m = root_tei.search(head)
        if not m:
            continue
        xid = m.group(1).decode("utf-8", errors="replace")
        xmlids.add(unicodedata.normalize("NFC", xid))

with open(basename_out, "w", encoding="utf-8") as out:
    out.write("".join(s + "\n" for s in sorted(basenames)))
with open(xmlid_out, "w", encoding="utf-8") as out:
    out.write("".join(s + "\n" for s in sorted(xmlids)))
PY
else
  : > "${basename_tmp}.raw"
  : > "${xmlid_tmp}.raw"
  while IFS= read -r path || [ -n "${path}" ]; do
    [ -z "${path}" ] && continue
    base=${path##*/}
    printf '%s\n' "${base%.xml}" >> "${basename_tmp}.raw"
    xid=$(
      xmllint --xpath 'string(/*[local-name()="TEI"]/@*[name()="xml:id" or local-name()="id"])' \
        "${path}" 2>/dev/null || true
    )
    if [ -n "${xid}" ]; then
      printf '%s\n' "${xid}" >> "${xmlid_tmp}.raw"
    fi
  done < "${files_tmp}"
  sort -u "${basename_tmp}.raw" > "${basename_tmp}.sorted"
  sort -u "${xmlid_tmp}.raw" > "${xmlid_tmp}.sorted"
  nfc_file "${basename_tmp}.sorted" "${basename_tmp}"
  nfc_file "${xmlid_tmp}.sorted" "${xmlid_tmp}"
  rm -f "${basename_tmp}.raw" "${basename_tmp}.sorted" "${xmlid_tmp}.raw" "${xmlid_tmp}.sorted"
fi

base_hits=$(comm -12 "${ids_tmp}" "${basename_tmp}" || true)
xmlid_hits=$(comm -12 "${ids_tmp}" "${xmlid_tmp}" || true)

if [ -n "${base_hits}" ] || [ -n "${xmlid_hits}" ]; then
  if [ -n "${base_hits}" ]; then
    echo "Retired id(s) still present as basename in ${root}:" >&2
    printf '%s\n' "${base_hits}" >&2
  fi
  if [ -n "${xmlid_hits}" ]; then
    echo "Retired id(s) still present as root TEI @xml:id in ${root}:" >&2
    printf '%s\n' "${xmlid_hits}" >&2
  fi
  echo "Remove the file(s) or drop the issued-id from ${manifest} if retirement was reversed." >&2
  exit 1
fi

echo "OK: no retired ids present ($(wc -l < "${ids_tmp}" | tr -d ' ') listed; basename + root @xml:id)"
