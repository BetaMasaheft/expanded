#!/usr/bin/env bash
# Discover expand shards (BetMasData-relative paths) from an expanded git tree.
#
# Modes (--mode / DISCOVER_MODE):
#   hybrid — L1 for works/persons/manuscripts/places/institutions (~170 jobs) +
#            matrix for narratives/studies/authority-files/corpora (~4 jobs);
#            recommended for full re-expand (~174 total).
#   l1     — one shard per L1 dir under each corpus (~205); skips orphan subtrees
#            with no BetMasData source (authority-files/new, …).
#   matrix — corpus-level shards for re-expand (~9 jobs); expanded-git orphans
#            absent from export are preserved on assemble (see assemble-shards).
#
# Optional filter: COLLECTION_FILTER or first non-option arg (explicit pilot path).
# Bash 3.2+ compatible (no mapfile).
set -euo pipefail

root=.
out_file=""
filter="${COLLECTION_FILTER:-}"
mode="${DISCOVER_MODE:-l1}"

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
    --mode)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --mode" >&2
        exit 2
      fi
      mode=$2
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

# BetMasData has no source for these L1 paths; expanded git may still hold trees
# (stale expanded-only dirs). assemble preserves any dest child absent from the
# export; discover skips them so expand jobs do not fail.
# IHA corpora are in the base image and are re-expanded like other shards.
is_skipped_orphan_shard() {
  case "$1" in
    authority-files/new)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

discover_l1_corpus() {
  local r=$1
  local corpus=$2
  local p rel
  if [ ! -d "${r}/${corpus}" ]; then
    return 0
  fi
  find "${r}/${corpus}" -mindepth 1 -maxdepth 1 -type d | sort | while IFS= read -r p; do
    rel="${p#"${r}"/}"
    if is_skipped_orphan_shard "${rel}"; then
      continue
    fi
    echo "${rel}"
  done
}

discover_l1() {
  local r=$1
  local name
  for name in works persons places institutions narratives studies authority-files manuscripts; do
    discover_l1_corpus "${r}" "${name}"
  done
  if [ -d "${r}/corpora" ]; then
    echo corpora
  fi
}

discover_hybrid() {
  local r=$1
  local name
  # Heavy corpora: L1 slices (~5 min each) avoid 240-min job limit and xst-get stalls.
  for name in works persons manuscripts places institutions; do
    discover_l1_corpus "${r}" "${name}"
  done
  # Light corpora: matrix-level jobs finish well within the timeout.
  for name in narratives studies authority-files; do
    if [ -d "${r}/${name}" ]; then
      echo "${name}"
    fi
  done
  if [ -d "${r}/corpora" ]; then
    echo corpora
  fi
}

discover_matrix() {
  local r=$1
  local name
  for name in works persons places institutions narratives studies authority-files manuscripts; do
    if [ -d "${r}/${name}" ]; then
      echo "${name}"
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
  case "${mode}" in
    hybrid)
      discover_hybrid "${root}" > "${tmp}"
      ;;
    l1)
      discover_l1 "${root}" > "${tmp}"
      ;;
    matrix)
      discover_matrix "${root}" > "${tmp}"
      ;;
    *)
      echo "Unknown mode: ${mode} (expected hybrid, l1, or matrix)" >&2
      exit 2
      ;;
  esac
fi

if [ ! -s "${tmp}" ]; then
  echo "No shards to expand" >&2
  exit 1
fi

cp "${tmp}" "${out_file}"
cat "${tmp}"
