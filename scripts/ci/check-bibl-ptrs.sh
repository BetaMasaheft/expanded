#!/usr/bin/env bash
# Fail if any expanded TEI bm: @target is absent from EthioStudies citations
# (@tag) and bibl-exceptions.xml (@bm). Offline gate for validate_* workflows.
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

ptrs_tmp=$(mktemp)
tags_tmp=$(mktemp)
exc_tmp=$(mktemp)
ok_tmp=$(mktemp)
miss_tmp=$(mktemp)
trap 'rm -f "${ptrs_tmp}" "${tags_tmp}" "${exc_tmp}" "${ok_tmp}" "${miss_tmp}"' EXIT

scan_ptrs() {
  local dir=$1 out=$2
  if command -v rg >/dev/null 2>&1; then
    rg -oN --no-filename -g '*.xml' 'target="bm:[^"]+"' "${dir}" 2>/dev/null \
      | sed -E 's/^target="//; s/"$//' \
      | sort -u >"${out}"
  else
    find "${dir}" -type f -name '*.xml' -print0 2>/dev/null \
      | xargs -0 grep -hoE 'target="bm:[^"]+"' 2>/dev/null \
      | sed -E 's/^target="//; s/"$//' \
      | sort -u >"${out}" || true
  fi
}

scan_ptrs "${root}" "${ptrs_tmp}"

grep -oE 'tag="bm:[^"]+"' "${citations}" 2>/dev/null \
  | sed -E 's/^tag="//; s/"$//' \
  | sort -u >"${tags_tmp}"

grep -oE 'bm="bm:[^"]+"' "${exceptions}" 2>/dev/null \
  | sed -E 's/^bm="//; s/"$//' \
  | sort -u >"${exc_tmp}"

sort -u "${tags_tmp}" "${exc_tmp}" >"${ok_tmp}"
comm -23 "${ptrs_tmp}" "${ok_tmp}" >"${miss_tmp}"

ptr_count=$(wc -l < "${ptrs_tmp}" | tr -d ' ')
tag_count=$(wc -l < "${tags_tmp}" | tr -d ' ')
exc_count=$(wc -l < "${exc_tmp}" | tr -d ' ')
miss_count=$(wc -l < "${miss_tmp}" | tr -d ' ')

printf 'bm: ptr coverage: %s distinct ptrs, %s EthioStudies tags, %s exceptions, %s missing\n' \
  "${ptr_count}" "${tag_count}" "${exc_count}" "${miss_count}"

if [ "${miss_count}" -eq 0 ]; then
  echo "bm: ptr coverage OK"
  exit 0
fi

while IFS= read -r id || [ -n "${id}" ]; do
  [ -n "${id}" ] || continue
  echo "MISSING bm: ptr: ${id}" >&2
done <"${miss_tmp}"
exit 1
