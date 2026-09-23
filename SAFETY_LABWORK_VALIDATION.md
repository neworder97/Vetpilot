# VetPilot safety and Labwork validation — 2026-09-23

Tested source: `65786643f03b77c8c3f6178ee575061ee8b6cd53` on `vetpilot-safety-labwork`.
Base: delivered `vetpilot-additive-migration` at `d761e7acb5071aacf6f8b0a4f9bc52791bfba70d`.

## Changes

- Applied the prior audited medication input, precision, daily-total division, rounding, formulation, duration and product-chart safeguards.
- Rejected non-finite and oversized nutrition weights before calorie rendering; added keyboard dismissal and stable accessibility identifiers.
- Added the final Labwork tab with provider filters and token-based search. Its 28 selected dog/cat entries cover 15 IDEXX and 13 Michigan State entries, including two explicitly unavailable MSU tests.
- Lab details include test purpose, submitted specimen amount, tube/additive, preparation, storage, and an official source link. Unknown volumes or centrifuge settings are explicitly left for laboratory confirmation. This is a selected quick reference, not either laboratory's full directory.
- Added reproducible current-source arithmetic CI plus iOS unit/UI validation using a checksum-pinned real canine thoracic radiograph. No injected diagnosis or synthetic radiograph replaces that fixture.

## Arithmetic evidence

[Current-source arithmetic run](https://github.com/neworder97/Vetpilot/actions/runs/35804571920) passed.

| Check | Result |
|---|---|
| Protocol branches / medication names | 307 / 114 |
| Weight × branch × dose-level cases | 9,210 |
| Independent numeric comparisons | 60,030; zero mismatches |
| Solid rounding cases | 14,580; zero boundary mismatches |
| Volume cases | 3,240; no nonzero volumes displayed as zero |
| Display errors over 5% | Zero |
| Rendered output comparisons | 72,094; zero failures |
| Extracted-core Swift tests | 75 passed |

The baseline reproduces 9 rounding boundary failures, 12 nonzero volumes shown as zero, 73 large display errors, and 3,373 rendered-output failures. These checks establish arithmetic behavior only.

## Branch scope

- `vetpilot-additive-migration`: delivered baseline, retained for regression comparison.
- `vetpilot-safety-audit-e2e`: differs from that baseline only by its audit workflow; it is not a corrected medication build.
- `vetpilot-safety-labwork`: corrected source and new Labwork work.
- `main`: diverged from the delivered migration. It was not replaced or claimed to have passed these checks.

## Release limitations

**Clinical release is not cleared. No final installable IPA is released by this work.**

1. The 307 protocol branches still require medication-by-medication current-source verification of indication, species, route, dose, schedule, concentration, duration, maximums, age limits, interactions and contraindications. A numerical pass does not validate the source dose or make tiny calculated volumes measurable with a particular syringe.
2. The X-ray service measures coarse image features and retrieves literature. It has no validated lesion-classification or organ-segmentation model. A successful import/result test is not diagnostic sensitivity, specificity, or real-world clinical validation.
3. This work does not test installation, camera behavior or performance on a physical iPhone, and does not configure signing credentials.
4. Laboratory requirements can change and vary by ordered panel. Use the linked official order instructions; do not infer unlisted volumes or centrifuge settings.

## iOS execution and build evidence

[Simulator and device-target build run](https://github.com/neworder97/Vetpilot/actions/runs/35804571880) passed on the same source commit.

- 86 iOS unit tests passed, zero failures.
- All 8 UI tests passed, zero failures: core dosing flow, injectable single-dose behavior, invalid concentration, demo navigation, real-radiograph import and production result, dog/cat nutrition, oversized nutrition input, and Labwork search/preparation.
- A real canine thorax fixture passed the production pipeline unit test and the photo-library-to-results UI test.
- The unsigned Release iphoneos target compiled successfully.
- Original bundled visual resources were restored and compared byte-for-byte successfully.
- Reviewed captured screenshots of the Labwork detail, X-ray results, nutrition invalid-input state and existing screens.
- Full logs and the xcresult screenshot attachments are retained in the run's `VetPilot-Safety-Labwork-Evidence` artifact. Arithmetic JSON, per-protocol CSV and Swift logs are in `VetPilot-Arithmetic-Evidence` on the arithmetic run.

No simulator failures remain in this tested suite. This result does not mean every possible interaction, device, clinical regimen or diagnosis has been validated.
