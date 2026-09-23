#!/usr/bin/env bash
# Drop shards and deletions already published from these source pins.
#
# A corpus is unchanged when provenance.json records the same betmasweb SHA,
# bibliography SHA, and corpus SHA as the image sources document. The corpus
# of a path is its first segment (manuscripts/EMML/1-1000 → manuscripts).
# An empty pin is never a match. A missing provenance.json publishes everything.
#
# @see https://github.com/BetaMasaheft/expanded/issues/40
set -euo pipefail

shards=""
removed=""
sources=""
provenance=""
out_shards=""
out_removed=""

usage() {
  echo "Usage: filter-provenance.sh --shards FILE --removed FILE --sources FILE --provenance FILE --out-shards FILE --out-removed FILE" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --shards)
      if [ "$#" -lt 2 ]; then usage; fi
      shards=$2
      shift 2
      ;;
    --removed)
      if [ "$#" -lt 2 ]; then usage; fi
      removed=$2
      shift 2
      ;;
    --sources)
      if [ "$#" -lt 2 ]; then usage; fi
      sources=$2
      shift 2
      ;;
    --provenance)
      if [ "$#" -lt 2 ]; then usage; fi
      provenance=$2
      shift 2
      ;;
    --out-shards)
      if [ "$#" -lt 2 ]; then usage; fi
      out_shards=$2
      shift 2
      ;;
    --out-removed)
      if [ "$#" -lt 2 ]; then usage; fi
      out_removed=$2
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done

if [ -z "${shards}" ] || [ -z "${removed}" ] || [ -z "${sources}" ] \
  || [ -z "${provenance}" ] || [ -z "${out_shards}" ] || [ -z "${out_removed}" ]; then
  usage
fi

if [ ! -f "${provenance}" ]; then
  echo "No provenance.json; publishing every shard." >&2
  cp "${shards}" "${out_shards}"
  cp "${removed}" "${out_removed}"
  exit 0
fi

unchanged=$(jq -r --slurpfile published "${provenance}" '
  . as $sources
  | $published[0] as $published
  | [ .corpora | keys[] | select(
      ($sources.betmasweb | type == "string") and ($sources.betmasweb != "")
      and ($sources.betmasweb == $published.betmasweb)
      and ($sources.bibliography | type == "string") and ($sources.bibliography != "")
      and ($sources.bibliography == $published.bibliography)
      and (($sources.corpora[.] // "") | type == "string")
      and (($sources.corpora[.] // "") != "")
      and (($sources.corpora[.] // "") == ($published.corpora[.] // ""))
    ) ] | .[]
' "${sources}")

keep_changed() {
  src=$1
  dest=$2
  : > "${dest}"
  while IFS= read -r path || [ -n "${path}" ]; do
    [ -z "${path}" ] && continue
    corpus=${path%%/*}
    if printf '%s\n' "${unchanged}" | grep -Fxq -- "${corpus}"; then
      echo "skip ${path} (${corpus} already published)" >&2
      continue
    fi
    printf '%s\n' "${path}" >> "${dest}"
  done < "${src}"
}

keep_changed "${shards}" "${out_shards}"
keep_changed "${removed}" "${out_removed}"
