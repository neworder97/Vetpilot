# VetPilot migration snapshot — September 22, 2026

This folder is intended to become the root of the replacement GitHub repository.
It contains direct Swift source; the old chunk/base64 reconstruction mechanism is not required here.

## Current intended app
The baseline is the user's original audited VetPilot app, with additions only:
- Original Dose, X-Ray, Breed and visual resources preserved.
- 114-medication / 307-preset audited medication catalog.
- Medication administration/dispensing additions: Low / Middle / High selection for ranges, solid/liquid administration math, rounding choices, delivered dose and quantity dispensing.
- Expanded breed reference: 54 dog breeds + 25 cat breeds.
- Nutrition tab for both dogs and cats: weight in lb/kg, BCS 1–9, Gain/Maintain/Lose goal, RER and daily kcal planning.

## Visual-resource preservation
A later build accidentally replaced the original compiled asset catalog with a much smaller generated catalog and omitted `VetPilotLogoSource.jpg`.
`PreservedOriginalBundleResources/` contains the exact resources recovered from the user's original IPA:
- `Assets.car`
- `AppIcon60x60@2x.png`
- `AppIcon76x76@2x~ipad.png`
- `VetPilotLogoSource.jpg`

The GitHub Actions workflow restores these files into the unsigned `.app` after Xcode compilation and before IPA packaging.
Do not remove this step unless the original artwork has been properly reconstructed into source asset catalogs and visually verified.

## Local audit status before migration
- Medication audit: PASS — 114 medications, 307 presets, 831 arithmetic cases, 0 errors.
- Administration/breed audit: PASS — 15 rounding fixtures, 54 dog breeds, 25 cat breeds, 0 errors.
- Nutrition audit: PASS — dog/cat and BCS coverage, 0 errors.

## Build status caveat
The pre-nutrition GitHub branch successfully built/tested/package an unsigned IPA.
Later nutrition CI retries ended before a macOS runner executed any steps, so that infrastructure event was not a Swift/test failure.
A corrected hybrid reference IPA is preserved in the full backup: original resources plus the newer Nutrition/MedAdmin/Breed executable.

## First steps in the new GitHub repo
1. Create an empty repository.
2. Upload the contents of this folder to the repository root (including `.github`).
3. Commit to `main`.
4. Open Actions and run `VetPilot iOS CI` manually if it does not start automatically.
5. Download the `FergusonVetPilot-Signulous-Unsigned` artifact and sign it with Signulous.

The original IPA should always remain archived as the visual/resource baseline.
