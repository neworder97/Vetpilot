# Migration baseline

Baseline app: FergusonVetPilot-Audited-114-Medications-Signulous-Unsigned(2).ipa (~1.9 MiB compressed IPA).
Development rule: upgrades are additive. Preserve the original visual bundle resources and existing app functionality.

Current additions:
- Medication administration: Low / Middle / High dose selection when a range exists; administration and dispense quantity math.
- Expanded breed reference: dogs and cats.
- Nutrition tab: dogs and cats, BCS 1-9, weight in lb/kg, gain/maintain/loss calorie planning.

The exact original Assets.car, app icons, and VetPilotLogoSource.jpg are stored under PreservedOriginalBundleResources and restored after the Release build before IPA packaging.
