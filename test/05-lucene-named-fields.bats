#!/usr/bin/env bats

# Contract between newSearch.html "#fields" rows (q:create-field-query)
# and Lucene <field name="..."> entries in collection.xconf.
# q:create-field-query emits `<parm>:(query)` from `*-field` params, so
# these names must exist as Lucene fields or the query matches nothing.

XCONF="${BATS_TEST_DIRNAME}/../collection.xconf"

check_fields() {
  python3 - "$XCONF" "$@" <<'PY'
import sys
import xml.etree.ElementTree as ET

ns = {"x": "http://exist-db.org/collection-config/1.0"}
root = ET.parse(sys.argv[1]).getroot()
text = root.find("x:index/x:lucene/x:text", ns)
if text is None:
    sys.exit("no lucene text index")
fields = {
    (el.get("name") or ""): (el.get("expression") or "")
    for el in text.findall("x:field", ns)
}

expected = [
    "signature",
    "decoDesc",
    "handDesc",
    "binding",
    "supportDesc",
    "msContent",
    "text",
    "colophon",
    "incipit",
    "explicit",
    "additions",
    "title",
    "place",
    "person",
]
missing = [name for name in expected if name not in fields]
if missing:
    sys.exit("missing Lucene fields: " + ", ".join(missing))
if "support" in fields:
    sys.exit("Lucene field still named 'support'; newSearch submits supportDesc")

person = fields["person"]
if "t:persName" not in person:
    sys.exit(f"person expression must include t:persName, got: {person}")
if person.startswith("t:body"):
    sys.exit(f"person expression must not use child t:body of t:TEI, got: {person}")

place = fields["place"]
if "t:placeName" not in place:
    sys.exit(f"place expression must include t:placeName, got: {place}")
if place.startswith("t:body"):
    sys.exit(f"place expression must not use child t:body of t:TEI, got: {place}")
PY
}

@test "lucene named fields match newSearch #fields rows and TEI structure" {
  run check_fields
  echo "$output"
  [ "$status" -eq 0 ]
}
