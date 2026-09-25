#!/usr/bin/env bash
# HP5: every uncommented deleted.xml item text must appear as issued-id/@id
# in retired-ids.xml (NFC-normalized), or in an optional exceptions file.
# Requires python3.
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

python3 - "$deleted" "$retired" "$exceptions" <<'PY'
import sys, unicodedata
from pathlib import Path
from xml.etree import ElementTree as ET

NS_TEI = {"t": "http://www.tei-c.org/ns/1.0"}
NS_BIM = {"bim": "https://betamasaheft.eu/betmas-id-manager"}

def nfc(s: str) -> str:
    return unicodedata.normalize("NFC", s.strip())

def load_exceptions(path: str) -> set[str]:
    if not path:
        return set()
    out: set[str] = set()
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        out.add(nfc(line))
    return out

deleted_path, retired_path, exceptions_path = sys.argv[1], sys.argv[2], sys.argv[3]
droot = ET.parse(deleted_path).getroot()
# ElementTree drops comments; items in comments are already excluded.
deleted_ids = {nfc(el.text) for el in droot.findall(".//t:item", NS_TEI) if el.text and el.text.strip()}
rroot = ET.parse(retired_path).getroot()
retired_ids = {nfc(el.get("id", "")) for el in rroot.findall("bim:issued-id", NS_BIM) if el.get("id")}
allowed = retired_ids | load_exceptions(exceptions_path)
missing = sorted(deleted_ids - allowed)
if missing:
    sys.stderr.write(f"HP5 FAIL: {len(missing)} deleted id(s) not in retired-ids or exceptions:\n")
    for i in missing:
        sys.stderr.write(f"  {i}\n")
    sys.exit(1)
exc_n = len(load_exceptions(exceptions_path))
print(f"OK: {len(deleted_ids)} deleted ids ⊆ {len(retired_ids)} retired ids (+{exc_n} exceptions)")
PY
