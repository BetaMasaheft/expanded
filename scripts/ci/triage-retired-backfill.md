# Retired-ids backfill triage (2026-09-25)

Source: `BetMas/db/apps/lists/deleted.xml` (snapshot: `scripts/ci/fixtures/deleted.xml.snapshot`)

## Summary

| Metric | Count |
|--------|------:|
| Unique uncommented deleted ids | 782 |
| Issued-id rows before backfill | 132 |
| Appended (deleted ∩ ¬retired) | 685 |
| Retired-only (retired ∩ ¬deleted) | 35 |
| Total issued-id rows after backfill | 817 |

## Resurrection gate overlap (deleted backfill vs expanded tree)

Nine ids were appended from `deleted.xml` but still exist as corpus XML basenames / root `@xml:id`. `check-retired-ids.sh --root .` fails until files are removed or ids are triaged out of the manifest:

- EMDA81 (note: `MotGeorg001` continuesAs=EMDA81 — rename successor still live)
- EMML1692
- INS0984MLQM
- LOC1464Ankoba
- LOC1886BetaLe
- LOC7458Hamburg
- NAR0183EtanaMogar
- PRS12461Tasamma
- UppEt18

## Retired-only ids (35)

Not in `deleted.xml`; existing rows left untouched:

ESmy026a, ESmy026b, HMK003, INS0970LeipzigUB, LIT1200Barthe, LIT2211Questi, LIT4148SalamAntonii, LIT4513Romewonna, MGeap001–MGeap009, MotGeorg001, PRS13652BatraM, PRS13832WaldaM, PRS13870GedayKidanu, PRS13990ZawaldaMaryam, PRS14012NehedranesAdreyasAbryas, PRS14030MaksimosManf%C9%99yosFiqtorFilpos, PRS14032MaksimosManf%C9%99yosFiqtorFilpos, PRS14033MaximusManius, PRS14057Qasero, PRS14064Tewogolos, PRS14070%E1%B8%A4abtaMG, PRS14120SendaqiTekku, PRS14150Za%CA%BEiy%C4%81sus, PRS14238Zaiyasus, PRS14297KefleYohannes, PRS14315Alkson, PRS9824Walatta

## Notes

- `retiredAt` set from `@change` date prefix when present on deleted items.
- ElementTree `--write` emits appended rows on one line; existing rows unchanged.
