#!/usr/bin/env bash
# Filter shard paths from GET /api/expand/shards.
#
# --missing-only drops paths whose directory already exists under --root
# (the expanded.git checkout). The image's own expanded collection can be
# older than that checkout, so "missing" is decided here, not in XQuery.
#
# @see https://github.com/BetaMasaheft/expanded/issues/40
set -euo pipefail

shards=""
root="."
out_file=""
missing_only=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --shards)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --shards" >&2
        exit 2
      fi
      shards=$2
      shift 2
      ;;
    --root)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --root" >&2
        exit 2
      fi
      root=$2
      shift 2
      ;;
    --out)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --out" >&2
        exit 2
      fi
      out_file=$2
      shift 2
      ;;
    --missing-only)
      missing_only=1
      shift
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

if [ -z "${shards}" ] || [ ! -f "${shards}" ]; then
  echo "usage: select-shards.sh --shards FILE --root DIR [--missing-only] [--out FILE]" >&2
  exit 2
fi

tmp=$(mktemp)
trap 'rm -f "${tmp}"' EXIT

while IFS= read -r rel || [ -n "${rel}" ]; do
  [ -z "${rel}" ] && continue
  rel="${rel#./}"
  if [ "${missing_only}" -eq 1 ] && [ -d "${root}/${rel}" ]; then
    continue
  fi
  printf '%s\n' "${rel}"
done < "${shards}" > "${tmp}"

if [ ! -s "${tmp}" ]; then
  echo "No shards to expand" >&2
  exit 1
fi

if [ -n "${out_file}" ]; then
  cp "${tmp}" "${out_file}"
fi
cat "${tmp}"
