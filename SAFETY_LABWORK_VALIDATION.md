# VetPilot 0.4.0 (4) — validation and release

Validated application source: `0ae2faa91ebb8847670686fd1ef94e578d85da86` on `vetpilot-safety-labwork`. Documentation updates after this commit do not change the IPA's source identity.

The unsigned IPA was created successfully and is ready for Signulous or another authorized signing service. It is not directly installable until signed. Artifact: [VetPilot-0.4.0-Signulous-IPA](https://github.com/neworder97/Vetpilot/actions/runs/35812969585/artifacts/10730947026).

SHA-256: `75d4de3c136825e69bd2aca841ef280b69ceffda611e85bbcd22cdbfed0e5717`

## Passed checks

[Arithmetic run](https://github.com/neworder97/Vetpilot/actions/runs/35812969532) and [iOS/release run](https://github.com/neworder97/Vetpilot/actions/runs/35812969585) both completed successfully on the same source.

| Check | Result |
|---|---|
| Preset branches / protocol medication names | 307 / 114 |
| Additional automatic medication entries | 27 |
| Weight × branch × level cases | 9,210, including blocked-eligibility checks |
| Independent numerical comparisons | 56,208; zero mismatches |
| Rendered-output comparisons | 68,710; zero failures |
| Solid-rounding / volume cases | 13,140 / 3,030 |
| Boundary mismatches / nonzero volumes shown as zero | Zero / zero |
| Extracted-core Swift tests | 91 passed |
| iOS unit / UI simulator tests | 98 / 10 passed; zero failures |
| Release iphoneos build | Passed |
| Restored original bundle resources | Byte-for-byte comparisons passed |
| IPA archive, arm64, version, bundle ID and checksum | Passed |

The IPA was downloaded and independently checked against the workflow manifest. Bundle ID is `com.ferguson.vetpilot`, version `0.4.0`, build `4`, platform `iPhoneOS`.

## Medication changes and limits

Source comparison is recorded for all 307 preset entries in `CLINICAL_SOURCE_REVIEW.json`: 213 source matches, 86 corrected entries with regression passes, four blocked entries, three limited-evidence references and one divergent reference. These categories are not clinical clearance.

Safeguards include finite inputs, unit conversions, daily-total division, tablet rounding, nonzero tiny-volume display, product-specific insulin and buprenorphine concentration guards, fixed-volume product mismatch rejection, source weight bands, maximum amounts, course limits and explicit final infusion concentration verification. Potassium now requires an entered veterinarian-prescribed rate and rejects values above 0.5 mEq/kg/hr; it does not select a midpoint. Ampicillin–sulbactam intermittent dosing explicitly uses combined drug mass.

Automatic calculations remain blocked for feline extended-release levetiracetam, the ambiguous feline cyclophosphamide cycle total, and dog/cat ampicillin–sulbactam CRI references with unresolved mass conventions. A reviewed individualized protocol is needed for these cases. The app must not invent missing clinical instructions.

Patient-specific eligibility, all interactions/contraindications and every commercial or compounded formulation have not been exhaustively validated. A mathematically valid volume does not prove that a particular syringe can measure it.

## X-ray and Labwork

The production X-ray pathway and photo-import UI passed with a checksum-pinned real canine radiograph. High/low confidence remains exploratory and uncalibrated, consistent with the requested scope; diagnostic performance has not been established.

The final Labwork tab contains 28 selected dog/cat entries: 15 IDEXX and 13 Michigan State, including two explicitly unavailable tests. Search/provider filtering accompanies purpose, specimen amount, tubes/additives, preparation, storage and official links. It is not either provider's full directory. Missing requirements remain explicitly unverified; current laboratory order instructions take precedence.

Physical iPhone installation and real camera capture have not been tested. Simulator test logs and screenshots are retained in the workflow evidence artifact.

## Branch scope

- `vetpilot-additive-migration`: delivered baseline used for regression comparison.
- `vetpilot-safety-audit-e2e`: baseline with an audit workflow; not a corrected medication build.
- `vetpilot-safety-labwork`: corrected application and Labwork implementation used for this IPA.
- `main`: diverged from the delivered migration; not replaced or claimed to pass.
