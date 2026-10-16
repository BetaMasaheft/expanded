#!/usr/bin/env bash
# Fail if any expanded TEI bm: @target is absent from EthioStudies citations
# (@tag) and bibl-exceptions.xml (@bm). Offline gate for validate_* workflows.
#
# Companion: betmas-e2e Phase 4 bibl coverage (live REST/XQuery). Keep scan
# scope and allowlist semantics aligned when either side changes.
#
# Requires ripgrep (rg). CI installs it; bare local without rg exits 2.
set -euo pipefail

root="."
citations=""
exceptions=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      root=$2
      shift 2
      ;;
    --citations)
      citations=$2
      shift 2
      ;;
    --exceptions)
      exceptions=$2
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 --root DIR --citations FILE --exceptions FILE" >&2
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

: "${citations:?--citations required}"
: "${exceptions:?--exceptions required}"

if [ ! -d "${root}" ]; then
  echo "expanded root not found: ${root}" >&2
  exit 2
fi
for path in "${citations}" "${exceptions}"; do
  if [ ! -f "${path}" ]; then
    echo "missing file: ${path}" >&2
    exit 2
  fi
done

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) required for bm: ptr scan" >&2
  exit 2
fi

ptrs_tmp=$(mktemp)
tags_tmp=$(mktemp)
exc_tmp=$(mktemp)
ok_tmp=$(mktemp)
miss_tmp=$(mktemp)
trap 'rm -f "${ptrs_tmp}" "${tags_tmp}" "${exc_tmp}" "${ok_tmp}" "${miss_tmp}"' EXIT

# First pipeline status: 0 = matches, 1 = no matches (empty OK), >=2 = error.
pipe_head_status() {
  local rc=${PIPESTATUS[0]}
  if [ "${rc}" -ge 2 ]; then
    echo "$1 scan failed (exit ${rc})" >&2
    exit "${rc}"
  fi
}

set +e
set +o pipefail
# Double-quoted target="bm:…" only (matches current corpus).
# Exclude CI fixtures so mini-bibl TEI never pollutes full-corpus scans.
rg -oN --no-filename -g '*.xml' -g '!**/scripts/ci/fixtures/**' \
  'target="bm:[^"]+"' "${root}" \
  | sed -E 's/^target="//; s/"$//' \
  | sort -u >"${ptrs_tmp}"
pipe_head_status "bm: ptr"

grep -oE 'tag="bm:[^"]+"' "${citations}" \
  | sed -E 's/^tag="//; s/"$//' \
  | sort -u >"${tags_tmp}"
pipe_head_status "citations tag"

grep -oE 'bm="bm:[^"]+"' "${exceptions}" \
  | sed -E 's/^bm="//; s/"$//' \
  | sort -u >"${exc_tmp}"
pipe_head_status "exceptions bm"
set -o pipefail
set -e

sort -u "${tags_tmp}" "${exc_tmp}" >"${ok_tmp}"
comm -23 "${ptrs_tmp}" "${ok_tmp}" >"${miss_tmp}"

ptr_count=$(wc -l < "${ptrs_tmp}" | tr -d ' ')
tag_count=$(wc -l < "${tags_tmp}" | tr -d ' ')
exc_count=$(wc -l < "${exc_tmp}" | tr -d ' ')
miss_count=$(wc -l < "${miss_tmp}" | tr -d ' ')

printf 'bm: ptr coverage: %s distinct ptrs, %s EthioStudies tags, %s exceptions, %s missing\n' \
  "${ptr_count}" "${tag_count}" "${exc_count}" "${miss_count}"

if [ "${ptr_count}" -eq 0 ]; then
  echo "ERROR: scan produced no bm: ptrs under ${root} (catastrophic empty scan?)" >&2
  exit 2
fi

if [ "${miss_count}" -eq 0 ]; then
  echo "bm: ptr coverage OK"
  exit 0
fi

while IFS= read -r id || [ -n "${id}" ]; do
  [ -n "${id}" ] || continue
  echo "MISSING bm: ptr: ${id}" >&2
done <"${miss_tmp}"
exit 1
