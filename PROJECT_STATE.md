# VetPilot project handoff state

## User requirement
Improve the original VetPilot app without removing existing functionality or artwork. New work is additive.

## Implemented code/features
- Dose calculator with audited source-backed protocol presets.
- 114 unique medications / 307 presets.
- Administration/dispense math with Low/Middle/High range choice when supported.
- Tablet/capsule raw unit calculation plus Round Down / Nearest Whole / Round Up; no automatic capsule splitting or assumption that tablets are scored.
- Liquid mL calculations and dispense quantity from frequency/duration.
- Breed reference expanded to 54 dog + 25 cat breeds with predisposition entries.
- Radiology/X-Ray tab retained.
- Nutrition tab for dog and cat.
- Nutrition inputs: species, current weight, lb/kg, BCS 1–9.
- BCS 1–3 = gain guidance; 4–5 = ideal/maintain; 6–9 = weight-loss planning.
- RER formula: 70 × kg^0.75.
- Weight-loss start: dog 1.0 × ideal-weight RER; cat 0.8 × ideal-weight RER.
- BCS >5 estimated ideal weight uses approximately 10% excess body weight per point above 5.
- Underweight calculations are labeled monitored starting ranges rather than a definitive ideal-weight prediction.

## Resource regression discovered
Original IPA versus latest nutrition IPA:
- Only completely missing file: `VetPilotLogoSource.jpg` (20,463 bytes).
- `Assets.car`: original 1,334,447 bytes; newer 389,967 bytes.
- `AppIcon60x60@2x.png`: changed.
- `AppIcon76x76@2x~ipad.png`: changed.
- Main executable grew from 2,821,824 bytes to 3,193,760 bytes, confirming feature code was added.
- Info.plist/package metadata were unchanged in the comparison.

Repair strategy: preserve original bundle resources and use the newer executable/source. The workflow in this migration repo performs that preservation before packaging.

## Last known old GitHub state
Repository: morningamerica97/Vetpilot
Feature branch: vetpilot-med-admin-breeds
Pull request: #1, still open/unmerged at last check.
Last observed nutrition-era branch head: dd7277263aedc22bd56882b112c38b059ca533db.
Earlier fully-green CI head before nutrition: 69a24647e8dbbfe07da15100df9e3918cde72e83.
Earlier successful workflow run: 35776474289.

The replacement repository should use this migration snapshot rather than depending on the old repository remaining available.
