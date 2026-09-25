#!/usr/bin/env bash
# HP5: every uncommented deleted.xml item text must appear as issued-id/@id
# in retired-ids.xml (NFC-normalized). Requires xmllint + python3.
set -euo pipefail

deleted=""
retired=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --deleted) deleted=$2; shift 2 ;;
    --retired) retired=$2; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

: "${deleted:?--deleted required}"
: "${retired:?--retired required}"

python3 - "$deleted" "$retired" <<'PY'
import sys, unicodedata
from xml.etree import ElementTree as ET

NS_TEI = {"t": "http://www.tei-c.org/ns/1.0"}
NS_BIM = {"bim": "https://betamasaheft.eu/betmas-id-manager"}

def nfc(s: str) -> str:
    return unicodedata.normalize("NFC", s.strip())

deleted_path, retired_path = sys.argv[1], sys.argv[2]
droot = ET.parse(deleted_path).getroot()
# ElementTree drops comments; items in comments are already excluded.
deleted_ids = {nfc(el.text) for el in droot.findall(".//t:item", NS_TEI) if el.text and el.text.strip()}
rroot = ET.parse(retired_path).getroot()
retired_ids = {nfc(el.get("id", "")) for el in rroot.findall("bim:issued-id", NS_BIM) if el.get("id")}
missing = sorted(deleted_ids - retired_ids)
if missing:
    sys.stderr.write(f"HP5 FAIL: {len(missing)} deleted id(s) not in retired-ids:\n")
    for i in missing:
        sys.stderr.write(f"  {i}\n")
    sys.exit(1)
print(f"OK: {len(deleted_ids)} deleted ids ⊆ {len(retired_ids)} retired ids")
PY
