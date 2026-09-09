#!/usr/bin/env bash
# Report ID-reservation stubs under {corpus}/new/ whose basename already
# exists outside new/ (record has "landed"; stub is overdue for removal).
#
# Default: warn and exit 0. Pass --strict to exit 1 when any overdue stub
# is found. Optional --betmas-data DIR also treats BetMasData paths outside
# new/ as landed (even when expanded has not re-exported them yet).
#
# Bash 3.2+ compatible.
set -euo pipefail

root=.
betmas_data=""
strict=0

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
    --betmas-data)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --betmas-data" >&2
        exit 2
      fi
      betmas_data=$2
      shift 2
      ;;
    --strict)
      strict=1
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

corpora="works persons places institutions narratives studies authority-files manuscripts"

stubs_tmp=$(mktemp)
landed_tmp=$(mktemp)
hits_tmp=$(mktemp)
trap 'rm -f "${stubs_tmp}" "${landed_tmp}" "${hits_tmp}"' EXIT

: > "${hits_tmp}"

basenames_under() {
  local base=$1
  shift
  # Remaining args are find -path prune patterns relative to base (optional).
  if [ ! -d "${base}" ]; then
    return 0
  fi
  if [ "$#" -gt 0 ]; then
    find "${base}" \( "$@" \) -prune -o -type f -name '*.xml' -print
  else
    find "${base}" -type f -name '*.xml' -print
  fi |
    while IFS= read -r path; do
      b=${path##*/}
      printf '%s\n' "${b%.xml}"
    done
}

for corpus in ${corpora}; do
  new_dir="${root}/${corpus}/new"
  if [ ! -d "${new_dir}" ]; then
    continue
  fi

  basenames_under "${new_dir}" | sort -u > "${stubs_tmp}"
  if [ ! -s "${stubs_tmp}" ]; then
    continue
  fi

  {
    basenames_under "${root}/${corpus}" -path "${root}/${corpus}/new"
    if [ -n "${betmas_data}" ] && [ -d "${betmas_data}/${corpus}" ]; then
      basenames_under "${betmas_data}/${corpus}" -path "${betmas_data}/${corpus}/new"
    fi
  } | sort -u > "${landed_tmp}"

  comm -12 "${stubs_tmp}" "${landed_tmp}" |
    while IFS= read -r id; do
      [ -z "${id}" ] && continue
      printf '%s\t%s\n' "${corpus}" "${id}"
    done >> "${hits_tmp}"
done

count=$(grep -c . "${hits_tmp}" 2>/dev/null || true)
# grep -c on empty may print 0; normalize
count=${count:-0}

if [ "${count}" -eq 0 ]; then
  echo "OK: no overdue new/ stubs"
  exit 0
fi

echo "Overdue new/ stubs (${count}) — id present outside new/ (stub should be removed):" >&2
while IFS=$'\t' read -r corpus id; do
  echo "  ${corpus}/new/${id}.xml" >&2
done < "${hits_tmp}"

if [ "${strict}" -eq 1 ]; then
  exit 1
fi
exit 0
