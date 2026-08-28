#!/usr/bin/env bash
# Merge shard artifacts into the expanded repo working tree (rsync --delete).
# Subdirectories present in the repo but absent from the export are preserved
# (expanded-git orphans with no BetMasData source, e.g. */IHA, authority-files/new).
# Validates every shard first so a later failure cannot leave a half-merged tree.
set -euo pipefail

manifest=""
shards_in=""
repo_root=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --manifest)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --manifest" >&2
        exit 2
      fi
      manifest=$2
      shift 2
      ;;
    --shards-in)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --shards-in" >&2
        exit 2
      fi
      shards_in=$2
      shift 2
      ;;
    --repo-root)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --repo-root" >&2
        exit 2
      fi
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

shard_lines=0
missing=0
while IFS= read -r rel || [ -n "${rel}" ]; do
  [ -z "${rel}" ] && continue
  shard_lines=$((shard_lines + 1))
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
  fi
done < "${manifest}"

if [ "${shard_lines}" -eq 0 ]; then
  echo "Empty shards manifest: ${manifest}" >&2
  exit 1
fi

if [ "${missing}" -ne 0 ]; then
  echo "One or more shard artifacts missing or empty" >&2
  exit 1
fi

while IFS= read -r rel || [ -n "${rel}" ]; do
  [ -z "${rel}" ] && continue
  rel="${rel#./}"
  src="${shards_in}/${rel}"
  count=$(find "${src}" -type f -name '*.xml' | wc -l | tr -d ' ')
  dest="${repo_root}/${rel}"
  mkdir -p "${dest}"
  rsync_args=(-a --delete)
  if [ -d "${dest}" ]; then
    for orphan in "${dest}"/*/; do
      [ -d "${orphan}" ] || continue
      name=$(basename "${orphan}")
      if [ ! -e "${src}/${name}" ]; then
        rsync_args+=(--exclude="${name}/")
        echo "preserve orphan ${rel}/${name} (absent from export)" >&2
      fi
    done
  fi
  rsync "${rsync_args[@]}" "${src}/" "${dest}/"
  echo "merged ${rel} (${count} xml)"
done < "${manifest}"

find "${repo_root}" -name '__contents__.xml' -delete 2>/dev/null || true
find "${repo_root}" -name '.shard-manifest' -delete 2>/dev/null || true
