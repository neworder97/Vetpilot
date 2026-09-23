# VetPilot safety and Labwork validation — 2026-09-23

The last completed validation is commit `37b3dc45a479fe885c1491115ec91bffbe412968`: arithmetic run 35810306723 and iOS run 35810306656 passed, with 95 unit and 9 UI tests, zero failures, a successful unsigned physical-device target build and byte-identical restored original visual resources.

The current candidate requires its own validation. It completes initial source comparison for all 307 protocol entries and adds explicit prescribed potassium rates, combined-mass antibiotic wording, blocked ambiguous CRI and chemotherapy cycle amounts, and source-specific anesthesia, behavioral and ophthalmic corrections. See `CLINICAL_SOURCE_REVIEW.json` for per-entry sources and limitations. Source matching is not clinical clearance.

## Release gate

The safety workflow now runs the independent numerical/rendered oracles and extracted-core Swift tests, then iOS unit/UI simulator tests, then the Release iphoneos build and original-resource comparisons. Only successful completion creates version 0.4.0 build 4 as an unsigned Signulous IPA. The generated release manifest records the exact source commit, run, IPA SHA-256 and validated archive structure. A failed check prevents packaging.

## Branch scope

- `vetpilot-additive-migration`: delivered baseline used for regression comparison.
- `vetpilot-safety-audit-e2e`: baseline with audit workflow; not a corrected build.
- `vetpilot-safety-labwork`: corrected source and Labwork implementation.
- `main`: diverged from the delivered migration; not replaced or claimed to pass.

## Features and coverage

- Dose safeguards cover finite inputs, unit conversions, daily totals, tablet rounding, tiny volume display, product-specific insulin and buprenorphine strengths, fixed-volume product mismatches, source weight bands, maximum amounts, duration and prescribed infusion rates.
- The final Labwork tab contains 28 selected dog/cat entries: 15 IDEXX and 13 Michigan State including two explicitly unavailable tests. Search/provider filtering and official source links accompany purpose, specimen, volume, tubes/additives, preparation and storage. This is not either provider's full directory. Unknown requirements remain explicitly unverified.
- X-ray validation includes a checksum-pinned real canine radiograph through the production analysis and photo-import UI. High/low confidence is exploratory and uncalibrated, not a disease probability or diagnostic validation.
- Simulator flows cover dosing, invalid inputs, insulin substitution, nutrition, Labwork and X-ray. Evidence includes logs, xcresult and screenshots.

## Remaining limits

Passing arithmetic and simulator checks does not validate every patient, indication, interaction, contraindication, commercial/compounded formulation or physical measuring device. Four unsupported/ambiguous presets remain blocked pending explicit individualized protocols. Other limited-evidence or divergent references remain qualified and high risk where applicable. Tiny calculated amounts do not establish syringe measurability.

Physical iPhone installation, real camera capture and clinical performance have not been tested. The IPA is unsigned and requires Signulous or another authorized signing route before installation. Laboratory instructions must be checked against the current ordered test.
