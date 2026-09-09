#!/usr/bin/env bash
# Merge shard artifacts into the expanded repo working tree (rsync --delete).
# Subdirectories present in the repo but absent from the export are preserved
# (expanded-git orphans with no BetMasData source, e.g. authority-files/new).
# Reservation folders named `new`:
#   - Parent corpus merges always exclude `new/` from the deleting rsync,
#     then overlay export/new/ without --delete (P3c) so BetMasData twins
#     update while expanded-only WIP stubs survive.
#   - Dedicated `{corpus}/new` shards merge the same way (no --delete).
#   - After overlay, drop overdue stubs whose basename already exists outside
#     `new/` under the same corpus (promoted / landed).
# Validates every shard first so a later failure cannot leave a half-merged tree.
set -euo pipefail

manifest=""
shards_in=""
repo_root=""
allow_partial=0

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
    --allow-partial)
      allow_partial=1
      shift
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

# Merge export/new → dest/new without --delete, then drop overdue stubs.
# $1 = source new/ dir, $2 = dest new/ dir, $3 = corpus root under repo
# (parent of new/), used to detect landed basenames outside new/.
merge_reservation_new() {
  local src_new=$1
  local dest_new=$2
  local corpus_root=$3
  local f base found

  mkdir -p "${dest_new}"
  rsync -a "${src_new}/" "${dest_new}/"
  echo "merged reservation ${dest_new#"${repo_root}"/} (no --delete)" >&2

  if [ ! -d "${dest_new}" ] || [ ! -d "${corpus_root}" ]; then
    return 0
  fi
  for f in "${dest_new}"/*.xml; do
    [ -f "${f}" ] || continue
    base=$(basename "${f}")
    found=$(find "${corpus_root}" -type f -name "${base}" ! -path "*/new/*" 2>/dev/null | head -n 1)
    if [ -n "${found}" ]; then
      rm -f "${f}"
      echo "dropped overdue reservation stub ${f#"${repo_root}"/} (landed at ${found#"${repo_root}"/})" >&2
    fi
  done
}

shard_lines=0
missing=0
present=0
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
    continue
  fi
  present=$((present + 1))
done < "${manifest}"

if [ "${shard_lines}" -eq 0 ]; then
  echo "Empty shards manifest: ${manifest}" >&2
  exit 1
fi

if [ "${missing}" -ne 0 ]; then
  if [ "${allow_partial}" -eq 1 ]; then
    echo "Partial assemble: ${present}/${shard_lines} shard(s) present; merging available only" >&2
  else
    echo "One or more shard artifacts missing or empty" >&2
    exit 1
  fi
fi

if [ "${present}" -eq 0 ]; then
  echo "No shard artifacts to merge" >&2
  exit 1
fi

while IFS= read -r rel || [ -n "${rel}" ]; do
  [ -z "${rel}" ] && continue
  rel="${rel#./}"
  src="${shards_in}/${rel}"
  if [ ! -d "${src}" ]; then
    continue
  fi
  count=$(find "${src}" -type f -name '*.xml' | wc -l | tr -d ' ')
  if [ "${count}" -eq 0 ]; then
    continue
  fi
  dest="${repo_root}/${rel}"

  case "${rel}" in
    */new)
      # Dedicated reservation shard (P3a/c).
      corpus_root="${repo_root}/${rel%/new}"
      merge_reservation_new "${src}" "${dest}" "${corpus_root}"
      echo "merged ${rel} (${count} xml)"
      continue
      ;;
  esac

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
  # Always exclude new/ from --delete; overlay separately without wipe (P3c).
  rsync_args+=(--exclude="new/")
  echo "defer reservation ${rel}/new (merge-safe overlay)" >&2
  rsync "${rsync_args[@]}" "${src}/" "${dest}/"
  if [ -d "${src}/new" ]; then
    merge_reservation_new "${src}/new" "${dest}/new" "${dest}"
  fi
  echo "merged ${rel} (${count} xml)"
done < "${manifest}"

find "${repo_root}" -name '__contents__.xml' -delete 2>/dev/null || true
find "${repo_root}" -name '.shard-manifest' -delete 2>/dev/null || true
