#!/usr/bin/env python3
"""Append issued-id rows for deleted.xml ids missing from retired-ids.xml."""
from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from pathlib import Path
from xml.etree import ElementTree as ET

NS_TEI = "http://www.tei-c.org/ns/1.0"
NS_BIM = "https://betamasaheft.eu/betmas-id-manager"
ET.register_namespace("", NS_BIM)

TYPE_BY_PREFIX = (
    ("LIT", "works"),
    ("PRS", "persons"),
    ("LOC", "places"),
    ("INS", "institutions"),
    ("NAR", "narratives"),
    ("AUTH", "authority-files"),
)


def nfc(s: str) -> str:
    return unicodedata.normalize("NFC", s.strip())


def infer_type(id_: str) -> str:
    for prefix, typ in TYPE_BY_PREFIX:
        if id_.startswith(prefix):
            return typ
    return "manuscripts"


def retired_at_from_change(change: str | None) -> str | None:
    if not change:
        return None
    # e.g. 2020-06-16T12-42-02.815+02-00 → 2020-06-16
    m = re.match(r"^(\d{4}-\d{2}-\d{2})", change)
    return m.group(1) if m else None


def load_deleted(path: Path) -> dict[str, str | None]:
    """id → optional @change (comments already omitted by ET)."""
    root = ET.parse(path).getroot()
    out: dict[str, str | None] = {}
    for el in root.iter(f"{{{NS_TEI}}}item"):
        if not el.text or not el.text.strip():
            continue
        i = nfc(el.text)
        out[i] = el.get("change")
    return out


def load_retired_ids(path: Path) -> set[str]:
    root = ET.parse(path).getroot()
    return {
        nfc(el.get("id", ""))
        for el in root.iter(f"{{{NS_BIM}}}issued-id")
        if el.get("id")
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--deleted", type=Path, required=True)
    ap.add_argument("--retired", type=Path, required=True)
    ap.add_argument("--write", action="store_true", help="rewrite retired file")
    args = ap.parse_args()

    deleted = load_deleted(args.deleted)
    retired = load_retired_ids(args.retired)
    missing = sorted(set(deleted) - retired)
    retired_only = sorted(retired - set(deleted))

    print(f"deleted unique: {len(deleted)}")
    print(f"retired: {len(retired)}")
    print(f"to append: {len(missing)}")
    print(f"retired-only (triage): {len(retired_only)}")

    if not args.write:
        for i in missing[:20]:
            print(f"  would add {i}")
        if len(missing) > 20:
            print(f"  ... {len(missing) - 20} more")
        return 0

    tree = ET.parse(args.retired)
    root = tree.getroot()
    for i in missing:
        attrs = {
            "id": i,
            "type": infer_type(i),
            "mode": "manual",
            "state": "retired",
            "reason": "deleted",
            "source": "lists/deleted.xml",
        }
        ra = retired_at_from_change(deleted.get(i))
        if ra:
            attrs["retiredAt"] = ra
        root.append(ET.Element(f"{{{NS_BIM}}}issued-id", attrs))

    tree.write(args.retired, encoding="UTF-8", xml_declaration=True)
    print(f"wrote {args.retired}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
