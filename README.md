# VetPilot — additive migration

This branch is the migration path for the verified VetPilot project. The original ~2 MB IPA is the baseline: upgrades must be additive and must not remove existing functionality or original visual resources.

## Required baseline

Original IPA size: **1,989,495 bytes**.

The migrated build must preserve the original `Assets.car`, app icons, `VetPilotLogoSource.jpg`, and original in-app Shepherd logo treatment while adding:

- Medication administration with Low / Middle / High selection when a protocol supplies a range.
- Administration and dispense quantity math.
- Expanded dog and cat breed predisposition reference.
- Dog and cat Nutrition tab with BCS 1–9, lb/kg entry, gain/maintain/loss guidance, and calorie planning.
- Existing medication, X-ray/radiology, and all other original VetPilot functionality.

The one-time workflow at `.github/workflows/import-vetpilot.yml` imports `VetPilot-Migration-Additive.zip`, commits the direct source, runs all audits/tests, restores the exact original bundle resources, and refuses to accept an IPA unless it is larger than the original 1,989,495-byte baseline.
