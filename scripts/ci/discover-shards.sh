#!/usr/bin/env bash
# Discover expand shards (BetMasData-relative paths) from an expanded git tree.
#
# Modes (--mode / DISCOVER_MODE):
#   hybrid — L1 for works/persons/manuscripts/places/institutions, with
#            manuscripts/EMML further split to L2 (~184 jobs) + matrix for
#            narratives/studies/authority-files/corpora (~4); ~188 total.
#   l1     — one shard per L1 dir under each corpus (~214 with EMML L2); skips
#            reservation / sourceless L1 dirs (`*/new`, …).
#   matrix — corpus-level shards for re-expand (~9 jobs); expanded-git orphans
#            absent from export are preserved on assemble (see assemble-shards).
#
# Optional filter: COLLECTION_FILTER or first non-option arg (pilot path).
# L2 parents (manuscripts/EMML) expand to their children — same as full hybrid/l1.
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

# Reservation folders (`{corpus}/new`) and other sourceless L1 trees must not
# become expand shards. assemble preserves `new/` under corpus merges; discover
# skips them so expand jobs do not fail or wipe ID-reservation stubs.
# IHA corpora are in the base image and are re-expanded like other shards.
is_skipped_orphan_shard() {
  case "$1" in
    */new)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# L1 dirs whose children are the expand/export unit (avoids 3h+ EMML jobs).
is_l2_shard_parent() {
  case "$1" in
    manuscripts/EMML)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

discover_l2_under() {
  local r=$1
  local parent=$2
  local p rel
  find "${r}/${parent}" -mindepth 1 -maxdepth 1 -type d | sort | while IFS= read -r p; do
    rel="${p#"${r}"/}"
    echo "${rel}"
  done
}

# Emit L2 children, or fall back to parent with a warning if none exist.
emit_l2_or_parent() {
  local r=$1
  local parent=$2
  local children
  children=$(discover_l2_under "${r}" "${parent}")
  if [ -z "${children}" ]; then
    echo "warning: ${parent} has no L2 children; using parent path" >&2
    echo "${parent}"
  else
    printf '%s\n' "${children}"
  fi
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
    if is_l2_shard_parent "${rel}"; then
      emit_l2_or_parent "${r}" "${rel}"
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
  # Heavy corpora: L1 slices; manuscripts/EMML → L2 (see is_l2_shard_parent).
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
  filter="${filter#./}"
  if is_skipped_orphan_shard "${filter}"; then
    echo "Refusing reservation/orphan shard filter: ${filter}" >&2
    exit 1
  fi
  if is_l2_shard_parent "${filter}"; then
    emit_l2_or_parent "${root}" "${filter}" > "${tmp}"
  else
    printf '%s\n' "${filter}" > "${tmp}"
  fi
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
