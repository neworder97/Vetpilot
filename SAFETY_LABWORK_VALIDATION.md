# VetPilot 0.4.2 (6) — general VetPilot branding

Validated source: `e7939b7c9f87bcc3c87569ba49419f38ddd10b22`.

Visible home and launch titles now say VetPilot. Hospital-specific subtitles and formulary wording were replaced with general veterinary/clinic wording. iOS display name, bundle display name and permission prompts also use VetPilot. Existing medication equations and features remain intact.

[Release validation](https://github.com/neworder97/Vetpilot/actions/runs/35816914049) passed, including 98 iOS unit tests, 10 UI tests, the arithmetic gate, device compilation, resource comparisons and IPA checks. Downloaded IPA metadata independently confirms VetPilot for both display and bundle names, version 0.4.2, build 6.

Unsigned [IPA artifact](https://github.com/neworder97/Vetpilot/actions/runs/35816914049/artifacts/10731889075), SHA-256: `5b7f96a6e28f41de238ae5ec4149aad3353f2c521f94f7952b1c9a80ab50207d`. Authorized signing is required. Prior clinical and physical-device validation limits still apply.

---

# VetPilot 0.4.1 (5) — additive quantity display

Validated source: `7bdcf59854049b99eed2e66c0960e45d158be1c6`.

[Release validation](https://github.com/neworder97/Vetpilot/actions/runs/35814903592) and [arithmetic audit](https://github.com/neworder97/Vetpilot/actions/runs/35814903576) passed. The suite includes 98 iOS unit tests, 10 UI tests and 96 extracted-core tests. Original visual resources, device-target compilation, IPA structure/version and checksum passed.

The result now adds the selected tablet/capsule equivalent and schedule, or injectable mL and schedule, alongside the existing calculation. It uses the existing selected-dose and per-administration arithmetic. Source equations, low/middle/high choices where applicable, frequency controls, rounding and existing administration details are preserved. Fractional capsules are not authorized for splitting; fractional tablets require product verification. Infusions retain mL/hr, and unresolved/high-risk administration plans retain their warnings.

New regression cases cover dose-level/strength changes, daily-total division, volume/concentration changes, fractional capsules and prescribed infusion rates. The simulator also asserts that the added tablet quantity is rendered beneath the result.

Unsigned IPA: [VetPilot-0.4.1-Signulous-IPA](https://github.com/neworder97/Vetpilot/actions/runs/35814903592/artifacts/10730394743). Authorized signing is required before installation.

SHA-256: `1bc22b54069eebf30e5ef4554e94415233f28b2bdb12f97290167182870901d7`.

This upgrade changes presentation, not medication catalog doses. The clinical limits and four blocked presets described in the original audit still apply. Physical-iPhone installation has not been tested.

---

## Previous release audit

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
