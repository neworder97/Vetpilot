# Ferguson VetPilot for iPhone

Native SwiftUI veterinary reference and radiology second-look app for iPhone.

## Current features
- Ferguson Animal Hospital branding and German Shepherd mark
- Dog and cat medication search, lb/kg conversion, formulation filters, and source-backed dose math
- 114-medication preloaded protocol library with second-audit unit safeguards (307 presets / 831 independent arithmetic cases)
- Administration planning with low/middle/high dose selection, whole tablet/capsule round-down/nearest/round-up display, delivered-dose comparison, frequency selection, and calculated dispense quantity
- Protocol locks for high-risk / indication-dependent medications
- Expanded breed predisposition library with search (54 dog breeds / 25 cat breeds)
- Dog/cat Nutrition tab with lb/kg weight entry, BCS 1–9, Gain/Maintain/Lose guidance, RER and daily kcal planning
- Radiology camera + Photos import
- On-device X-ray precheck and real pixel-based image measurements
- Pattern observations for contrast, tonal range, sharpness, density asymmetry, center/periphery differences, and regional heterogeneity
- Projection-aware wording when the study field includes lateral, VD, DV, AP, or PA
- Free live PubMed cross-reference over Wi-Fi/cellular when available
- Curated veterinary radiology references even when the live lookup is offline
- Local clinician-confirmed case memory for review context

## Radiology scope
The X-ray feature is a second-look decision-support tool, not a replacement for a veterinarian or board-certified veterinary radiologist. This build does not claim to be a validated lesion-classification model. It reports measurable image patterns and broad possibilities, and it explicitly keeps literature matches separate from image findings.

The radiograph itself stays on the iPhone. Only text search terms are sent to PubMed for live literature lookup. No OpenAI API key or paid per-scan AI service is required.

## Validation
CI runs the production image analyzer on iOS Simulator. The workflow downloads a real CC BY-SA canine VD thoracic radiograph from Wikimedia Commons for the radiology pipeline test; no fake diagnosis or UI-test differential is injected.

## Open on your Mac
1. Install current Xcode.
2. Install XcodeGen with Homebrew: `brew install xcodegen`.
3. In Terminal, `cd` to this repository root and run `xcodegen generate`.
4. Open `FergusonVetPilot.xcodeproj`.
5. Pick an iPhone Simulator and press Run.
6. For a physical iPhone, choose your Apple account/team under Signing & Capabilities.


## Medication administration math
- VetPilot preserves the full source-backed dose range and lets the veterinarian select the low, mathematical midpoint, or high end.
- Solid-dose conversion is `selected mg ÷ product strength mg = raw tablets/capsules`. The app then displays whole-unit round-down, nearest-whole, or round-up choices, the delivered mg, delivered mg/kg, and percentage difference from the selected target. It does not assume tablets are scored and never splits capsules automatically.
- Liquid/injectable conversion uses the verified product concentration and the audited unit contract: mass products in mg/mL, insulin in units/mL, electrolytes in mEq/mL, with explicit mcg↔mg conversion for mcg-based protocols.
- Dispense quantity is derived only after a schedule and duration are selected. It remains math support, not an authorization to prescribe, dispense, or administer.
- Oncology mg/m² math retains the audited dog/cat BSA constants used by the Merck/MSD veterinary conversion tables. High-risk protocols remain veterinarian-gated.

## Audits
`Scripts/second_audit.py` validates the 114-medication preload and critical dose/unit corrections. `Scripts/administration_audit.py` independently checks administration rounding, critical unit-conversion examples, BSA examples, required safety behavior, and breed-library coverage. `Scripts/nutrition_audit.py` checks the dog/cat BCS calorie planner. GitHub Actions runs all three audits plus the Swift unit tests, restores the exact original visual bundle resources, and then packages the unsigned IPA.

## Original visual resources
The original IPA is the visual/resource baseline. `PreservedOriginalBundleResources/` contains the exact `Assets.car`, app icons, and `VetPilotLogoSource.jpg` recovered from that IPA. The CI workflow restores them after compilation so future builds do not repeat the stripped-assets regression.
