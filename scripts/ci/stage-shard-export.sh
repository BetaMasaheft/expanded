#!/usr/bin/env bash
# Stage an already-exported xst tree into shard-out/<rel>/. Does not call xst.
set -euo pipefail

rel=""
export_root=""
artifact_root=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --rel)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --rel" >&2
        exit 2
      fi
      rel=$2
      shift 2
      ;;
    --export-root)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --export-root" >&2
        exit 2
      fi
      export_root=$2
      shift 2
      ;;
    --artifact-root)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --artifact-root" >&2
        exit 2
      fi
      artifact_root=$2
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "${rel}" ] || [ -z "${export_root}" ] || [ -z "${artifact_root}" ]; then
  echo "usage: stage-shard-export.sh --rel PATH --export-root DIR --artifact-root DIR" >&2
  exit 2
fi

rel="${rel#./}"
leaf="${rel##*/}"
src="${export_root}/${leaf}"
if [ ! -d "${src}" ]; then
  echo "xst get did not produce ${src}" >&2
  exit 1
fi

# Count before staging so a zero-xml export leaves no partial artifact tree.
count=$(find "${src}" -type f -name '*.xml' ! -name '__contents__.xml' | wc -l | tr -d ' ')
if [ "${count}" -eq 0 ]; then
  echo "Exported 0 xml files for ${rel}; refusing empty shard" >&2
  exit 1
fi

dest="${artifact_root}/${rel}"
mkdir -p "$(dirname "${dest}")"
mkdir -p "${dest}"
rsync -a "${src}/" "${dest}/"
find "${dest}" -name '__contents__.xml' -delete 2>/dev/null || true

# Re-count after dropping __contents__.xml (should match pre-count).
count=$(find "${dest}" -type f -name '*.xml' | wc -l | tr -d ' ')
echo "${rel} ${count}" > "${artifact_root}/.shard-manifest"
echo "Exported ${rel} (${count} xml files)"
if [ "${count}" -eq 0 ]; then
  echo "Exported 0 xml files for ${rel}; refusing empty shard" >&2
  exit 1
fi
