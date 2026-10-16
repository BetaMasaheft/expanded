# Reference-gate pins

Used by Validate PR / Validate Push (`checkout-reference-gates` action).

| File | Repo | What it pins |
|------|------|----------------|
| `bibliography.sha` | `BetaMasaheft/bibliography` | `citations.xml` for the fail-closed `bm:` ptr gate |
| `betmas.sha` | `BetaMasaheft/BetMas` | `bibl-exceptions.xml`, `place-labels.xml`, `scripts/place-labels` |

## Bump order

1. **Bibliography re-export / exceptions change** — land BetMas `bibl-exceptions.xml` update first (if any), then set `bibliography.sha` to the bibliography commit that matches that triage, then bump `betmas.sha` to the BetMas commit that contains the new exceptions.
2. **Place-labels artifact or checker only** — bump `betmas.sha` alone after the BetMas merge.
3. Open an expanded PR that only updates the pin file(s) and green CI.

Do not float `ref: master` for BetMas in validate workflows — pins keep expanded CI reproducible.

## Related gates

- Offline expanded `scripts/ci/check-bibl-ptrs.sh` (this repo).
- Live/DB coverage in **betmas-e2e** Phase 4 bibl checks — keep policies aligned when changing scan scope or normalization.
