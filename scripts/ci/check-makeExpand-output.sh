#!/usr/bin/env bash
# Validate makeExpand.xql response body. Exit 0 only for "expanded N …" with N>=1.
set -euo pipefail

if [ "$#" -ge 1 ]; then
  out=$1
else
  out=$(cat)
fi

# Require a positive integer count (no leading zeros). Optional trailing text.
if printf '%s' "${out}" | grep -Eq '^expanded ([1-9][0-9]*)( |$)'; then
  exit 0
fi

echo "makeExpand unexpected or zero output: ${out}" >&2
exit 1
