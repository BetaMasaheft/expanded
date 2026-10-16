#!/usr/bin/env bash
# Fail when external place refs in expanded TEI are missing from place-labels.xml
# (and scripts/place-labels/exceptions.txt). Delegates to BetMas HP6 checker.
set -euo pipefail

root="."
betmas=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      root=$2
      shift 2
      ;;
    --betmas)
      betmas=$2
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 --root DIR --betmas DIR" >&2
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

: "${betmas:?--betmas required}"

checker="${betmas}/scripts/place-labels/check_coverage.sh"
artifact="${betmas}/db/apps/catalogs/place-labels.xml"

if [ ! -f "${checker}" ]; then
  echo "BetMas place-labels checker missing: ${checker}" >&2
  exit 2
fi
if [ ! -f "${artifact}" ]; then
  echo "place-labels artifact missing: ${artifact}" >&2
  exit 2
fi

export EXPANDED_ROOT="${root}"
export ARTIFACT="${artifact}"
export PLACE_LABELS_STRICT=1

bash "${checker}"
