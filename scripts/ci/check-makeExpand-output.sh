#!/usr/bin/env bash
# Validate makeExpand.xql response body. Exit 0 only for "expanded N …" with N>=1.
set -euo pipefail

if [ "$#" -ge 1 ]; then
  out=$1
else
  out=$(cat)
fi

case "${out}" in
  expanded\ 0\ *)
    echo "makeExpand processed 0 files: ${out}" >&2
    exit 1
    ;;
  expanded\ *)
    exit 0
    ;;
  *)
    echo "makeExpand unexpected output: ${out}" >&2
    exit 1
    ;;
esac
