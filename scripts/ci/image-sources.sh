#!/usr/bin/env bash
# Turn release-expanded OCI labels into the publication watermark.
#
# eu.betamasaheft.ref.narrative is the narratives corpus. traces and the
# app repos that are not expand inputs are dropped. A missing label is an
# empty pin, which is never treated as "already published".
#
# @see https://github.com/BetaMasaheft/expanded/issues/40
set -euo pipefail

labels=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --labels)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --labels" >&2
        exit 2
      fi
      labels=$2
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "${labels}" ] || [ ! -f "${labels}" ]; then
  echo "image-sources: --labels FILE is required" >&2
  exit 2
fi

jq -n --slurpfile labels "${labels}" '
  ($labels[0] // {}) as $labels
  | def pin($key):
      ($labels["eu.betamasaheft.ref." + $key] // "")
      | if type == "string" then . else "" end;
  {
    version: 1,
    betmasweb: pin("betmasweb"),
    bibliography: pin("bibliography"),
    corpora: {
      manuscripts: pin("manuscripts"),
      works: pin("works"),
      persons: pin("persons"),
      places: pin("places"),
      institutions: pin("institutions"),
      narratives: pin("narrative"),
      studies: pin("studies"),
      "authority-files": pin("authority-files"),
      corpora: pin("corpora")
    }
  }
'
