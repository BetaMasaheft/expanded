#!/usr/bin/env bash
# Delete checkout directories named by GET /api/expand/deletions.
#
# The path list is the image's decision. This script does not discover
# shards. It refuses */new and any path with .., and deletes nothing if
# any line is refused.
#
# @see https://github.com/BetaMasaheft/expanded/issues/40
set -euo pipefail

paths=""
root=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --paths)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --paths" >&2
        exit 2
      fi
      paths=$2
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

if [ -z "${paths}" ] || [ ! -f "${paths}" ] || [ -z "${root}" ]; then
  echo "usage: prune-absent-shards.sh --paths FILE --root DIR" >&2
  exit 2
fi

refused=0
while IFS= read -r rel || [ -n "${rel}" ]; do
  [ -z "${rel}" ] && continue
  rel="${rel#./}"
  case "${rel}" in
    "" | .* | /* | */.. | */../* | new | */new)
      echo "Refusing path: ${rel}" >&2
      refused=1
      ;;
  esac
done < "${paths}"

if [ "${refused}" -ne 0 ]; then
  echo "Refused to delete any path" >&2
  exit 1
fi

root_real=$(CDPATH='' cd "${root}" && pwd)
while IFS= read -r rel || [ -n "${rel}" ]; do
  [ -z "${rel}" ] && continue
  rel="${rel#./}"
  target="${root}/${rel}"
  if [ ! -d "${target}" ]; then
    echo "already absent ${rel}"
    continue
  fi
  parent_real=$(CDPATH='' cd "$(dirname "${target}")" && pwd)
  case "${parent_real}" in
    "${root_real}" | "${root_real}"/*) ;;
    *)
      echo "Refusing path outside root: ${rel}" >&2
      exit 1
      ;;
  esac
  rm -rf "${target}"
  echo "removed ${rel}"
done < "${paths}"
