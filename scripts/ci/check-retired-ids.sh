#!/usr/bin/env bash
# Fail if any retired basename from config/retired-ids.txt is present as a
# *.xml file in the expanded tree (blocks re-expand / assemble resurrection).
# Bash 3.2+ compatible.
set -euo pipefail

root=.
manifest=""

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
    --manifest)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --manifest" >&2
        exit 2
      fi
      manifest=$2
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

if [ -z "${manifest}" ]; then
  manifest="${root}/config/retired-ids.txt"
fi

if [ ! -f "${manifest}" ]; then
  echo "Missing retired-ids manifest: ${manifest}" >&2
  exit 1
fi

ids_tmp=$(mktemp)
present_tmp=$(mktemp)
trap 'rm -f "${ids_tmp}" "${present_tmp}"' EXIT

# First field only; skip comments/blank lines.
while IFS= read -r line || [ -n "${line}" ]; do
  case "${line}" in
    '' | \#*)
      continue
      ;;
  esac
  # First whitespace-separated field.
  # shellcheck disable=SC2086
  set -- ${line}
  id=$1
  if [ -n "${id}" ]; then
    printf '%s\n' "${id}"
  fi
done < "${manifest}" | sort -u > "${ids_tmp}"

if [ ! -s "${ids_tmp}" ]; then
  echo "retired-ids manifest has no ids: ${manifest}" >&2
  exit 1
fi

# Present basenames under root (exclude test fixtures / build / .git).
find "${root}" \
  \( -path "${root}/test" -o -path "${root}/.git" -o -path "${root}/build" \) -prune \
  -o -type f -name '*.xml' -print |
  while IFS= read -r path; do
    base=${path##*/}
    printf '%s\n' "${base%.xml}"
  done |
  sort -u > "${present_tmp}"

hits=$(comm -12 "${ids_tmp}" "${present_tmp}" || true)
if [ -n "${hits}" ]; then
  echo "Retired id(s) still present in ${root}:" >&2
  printf '%s\n' "${hits}" >&2
  echo "Remove the file(s) or drop the id from ${manifest} if retirement was reversed." >&2
  exit 1
fi

echo "OK: no retired ids present ($(wc -l < "${ids_tmp}" | tr -d ' ') listed)"
