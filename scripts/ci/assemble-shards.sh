#!/usr/bin/env bash
# Merge shard artifacts into the expanded repo working tree (rsync --delete).
set -euo pipefail

manifest=""
shards_in=""
repo_root=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --manifest)
      manifest=$2
      shift 2
      ;;
    --shards-in)
      shards_in=$2
      shift 2
      ;;
    --repo-root)
      repo_root=$2
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "${manifest}" ] || [ -z "${shards_in}" ] || [ -z "${repo_root}" ]; then
  echo "usage: assemble-shards.sh --manifest FILE --shards-in DIR --repo-root DIR" >&2
  exit 2
fi

if [ ! -f "${manifest}" ]; then
  echo "Missing shards manifest: ${manifest}" >&2
  exit 1
fi

missing=0
while IFS= read -r rel || [ -n "${rel}" ]; do
  [ -z "${rel}" ] && continue
  rel="${rel#./}"
  src="${shards_in}/${rel}"
  if [ ! -d "${src}" ]; then
    echo "Missing artifact tree for ${rel} (expected ${src})" >&2
    missing=1
    continue
  fi
  count=$(find "${src}" -type f -name '*.xml' | wc -l | tr -d ' ')
  if [ "${count}" -eq 0 ]; then
    echo "Shard ${rel} has 0 xml files; refusing rsync --delete wipe" >&2
    missing=1
    continue
  fi
  dest="${repo_root}/${rel}"
  mkdir -p "${dest}"
  rsync -a --delete "${src}/" "${dest}/"
  echo "merged ${rel} (${count} xml)"
done < "${manifest}"

find "${repo_root}" -name '__contents__.xml' -delete 2>/dev/null || true
find "${repo_root}" -name '.shard-manifest' -delete 2>/dev/null || true

if [ "${missing}" -ne 0 ]; then
  echo "One or more shard artifacts missing or empty" >&2
  exit 1
fi
