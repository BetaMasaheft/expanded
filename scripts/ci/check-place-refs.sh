#!/usr/bin/env bash
# External place refs in expanded TEI vs BetMas place-labels.xml (HP6).
#
# Default: warn-only (PLACE_LABELS_STRICT unset) so expanded validate stays
# green while the HP6 backlog burns down — same policy as BetMas #234.
# Set PLACE_LABELS_STRICT=1 in the environment to fail CI on missing refs.
#
# Delegates to BetMas scripts/place-labels/check_coverage.sh.
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
      echo "  PLACE_LABELS_STRICT=1  fail on missing refs (default: warn)" >&2
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
# Inherit PLACE_LABELS_STRICT if set; do not default to 1 (option A / #44).

bash "${checker}"
