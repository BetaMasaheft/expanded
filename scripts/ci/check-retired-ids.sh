#!/usr/bin/env bash
# Fail if any retired @id from config/retired-ids.xml is present as a
# *.xml basename in the expanded tree (blocks re-expand / assemble
# resurrection). Manifest shape mirrors betmas-id-manager bim:issued-id.
# Bash 3.2+ compatible; requires grep/sed (no Python).
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
  manifest="${root}/config/retired-ids.xml"
fi

if [ ! -f "${manifest}" ]; then
  echo "Missing retired-ids manifest: ${manifest}" >&2
  exit 1
fi

ids_tmp=$(mktemp)
present_tmp=$(mktemp)
trap 'rm -f "${ids_tmp}" "${present_tmp}"' EXIT

# issued-id elements are single-line; pull @id (attribute order may vary).
grep -E '<issued-id[\t ]' "${manifest}" |
  grep -oE 'id="[^"]+"' |
  sed 's/^id="//; s/"$//' |
  sort -u > "${ids_tmp}"

if [ ! -s "${ids_tmp}" ]; then
  echo "retired-ids manifest has no issued-id/@id: ${manifest}" >&2
  exit 1
fi

# Present basenames under root (exclude test fixtures / build / .git / config).
find "${root}" \
  \( -path "${root}/test" -o -path "${root}/.git" -o -path "${root}/build" -o -path "${root}/config" \) -prune \
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
  echo "Remove the file(s) or drop the issued-id from ${manifest} if retirement was reversed." >&2
  exit 1
fi

echo "OK: no retired ids present ($(wc -l < "${ids_tmp}" | tr -d ' ') listed)"
