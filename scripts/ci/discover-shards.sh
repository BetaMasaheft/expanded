#!/usr/bin/env bash
# Discover L1 expand shards under an expanded (or fixture) tree.
# Optional filter: COLLECTION_FILTER or first non-option arg.
# Bash 3.2+ compatible (no mapfile).
set -euo pipefail

root=.
out_file=""
filter="${COLLECTION_FILTER:-}"

while [ "$#" -gt 0 ]; do
  case "$1" in
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
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
    *)
      filter=$1
      shift
      break
      ;;
  esac
done

if [ -z "${out_file}" ]; then
  out_file="${root}/shards.txt"
fi

discover_slices() {
  local r=$1
  local name
  for name in works persons places institutions narratives studies authority-files manuscripts; do
    if [ -d "${r}/${name}" ]; then
      find "${r}/${name}" -mindepth 1 -maxdepth 1 -type d | sort | while IFS= read -r p; do
        echo "${p#"${r}"/}"
      done
    fi
  done
  if [ -d "${r}/corpora" ]; then
    echo corpora
  fi
}

tmp=$(mktemp)
trap 'rm -f "${tmp}"' EXIT

if [ -n "${filter}" ]; then
  printf '%s\n' "${filter#./}" > "${tmp}"
else
  discover_slices "${root}" > "${tmp}"
fi

if [ ! -s "${tmp}" ]; then
  echo "No shards to expand" >&2
  exit 1
fi

cp "${tmp}" "${out_file}"
cat "${tmp}"
