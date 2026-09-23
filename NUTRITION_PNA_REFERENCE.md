# Nutrition calculator reference check

Reviewed: 2026-09-23 UTC. This documents the observed **PNA calculator method**,
not a universal calorie prescription or clinical validation of individual patients.

## Evidence and limits

- User-specified calculator: https://petnutritionalliance.org/resources/calorie-calculator/?type=dogs
- The public page and its current JavaScript bundle were retrieved successfully.
- Bundle: https://petnutritionalliance.org/wp-content/themes/custom/bundles/production.22af2e.js?ver=7.0.6
- Bundle SHA-256: `9bd2de3061fecf057dacfa6d3f8a9c2127ab35df0b4897da3f5046a4b9dd35a9`.
- Retrieved algorithm was executed separately with synthetic inputs to obtain 42
  reference cases. These are an independent source oracle for the Swift implementation.
- No PNA source code was added to this repository. The implementation is independent.
- A live browser navigation stalled and was interrupted. **No live browser result
  was confirmed.** The table below is from the retrieved algorithm, not UI screenshots.
- The site states its formulas may change. Recheck source and behavior before
  claiming parity with a later PNA release.

## Observed calculation contract

1. Inputs: dog/cat, positive current weight, lb/kg, BCS, reproductive status,
   and optional positive current daily calories.
2. PNA automatic calculations are unavailable for dogs below BCS 4.5 and cats
   below BCS 4. With the app's integer scores, this means dog 1–4 and cat 1–3.
3. At BCS 4.5–5.5, ideal weight equals entered current weight without preliminary
   rounding. At cat BCS 4, ideal weight is current weight × 1.05, rounded to one
   decimal in the entered unit. At BCS above 5.5, ideal weight is current weight /
   [1 + (BCS − 5) / 10], rounded to one decimal in the entered unit.
4. Convert the resulting weight to kg using lb / 2.205. This PNA conversion and
   entered-unit rounding belong only to nutrition, not medication calculations.
5. Unmultiplied ideal-weight RER = 70 × ideal kg^0.75. The minimum is this RER ×
   0.60 rounded to whole kcal, before any maintenance multiplier.
6. With current intake blank, BCS 4.5–5.5 baseline calories are RER × 1.4 for a
   spayed/neutered dog, × 1.6 for an intact dog, × 1.2 for a spayed/neutered cat,
   or × 1.4 for an intact cat. Other supported BCS use unmultiplied ideal RER.
   Round this baseline to whole kcal before applying the reduction below.
7. With current intake supplied, it replaces the baseline above. Reproductive
   status does not multiply supplied intake. Do not round supplied intake before
   applying the reduction.
8. Reduce baseline by 10% at BCS >5.5 and <7, by 20% at BCS ≥7, otherwise by 0%.
   Round the result to whole kcal. All positive-number rounding uses nearest,
   with exact halves rounded up, matching JavaScript `Math.round`.
9. If recommended calories fall below the rounded 60%-of-ideal-RER minimum,
   withhold automatic recommended calories and request nutritional assessment.
   This rule also applies at healthy BCS when supplied intake is too low.
10. Reproductive status affects only the healthy-BCS estimated baseline. It does
    not add a maintenance multiplier to a weight-loss plan.

## Reference cases from separately executed PNA algorithm

Intake is blank unless stated. Ideal weight uses the entered unit. Results are
whole kcal/day. Spayed/neutered is abbreviated S/N.

| Species | Weight | BCS | Status | Intake | Ideal | Baseline | Recommended | Minimum |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| Dog | 20 kg | 5 | S/N | — | 20 kg | 927 | 927 | 397 |
| Dog | 20 kg | 5 | Intact | — | 20 kg | 1059 | 1059 | 397 |
| Dog | 20 kg | 6 | Either | — | 18.2 kg | 617 | 555 | 370 |
| Dog | 20 kg | 7 | Either | — | 16.7 kg | 578 | 462 | 347 |
| Dog | 20 kg | 9 | Either | — | 14.3 kg | 515 | 412 | 309 |
| Dog | 44.1 lb | 6 | S/N | — | 40.1 lb | 616 | 554 | 370 |
| Dog | 44.1 lb | 9 | S/N | — | 31.5 lb | 514 | 411 | 309 |
| Cat | 5 kg | 4 | Either | — | 5.3 kg | 245 | 245 | 147 |
| Cat | 5 kg | 5 | S/N | — | 5 kg | 281 | 281 | 140 |
| Cat | 5 kg | 5 | Intact | — | 5 kg | 328 | 328 | 140 |
| Cat | 5 kg | 6 | Either | — | 4.5 kg | 216 | 194 | 130 |
| Cat | 5 kg | 7 | Either | — | 4.2 kg | 205 | 164 | 123 |
| Cat | 11.025 lb | 7 | S/N | — | 9.2 lb | 204 | 163 | 123 |
| Dog | 20 kg | 7 | S/N | 400 | 16.7 kg | 400 | Unavailable | 347 |
| Dog | 20 kg | 7 | S/N | 497 | 16.7 kg | 497 | 398 | 347 |
| Dog | 20 kg | 7 | S/N | 600 | 16.7 kg | 600 | 480 | 347 |

## Interpretation and clinical distinctions

- Weight status is derived from the selected body-condition score and a physical
  nutritional assessment; body weight alone does not establish obesity.
- AAHA 2021 recommends extended assessment for BCS <4/9 or >5/9. Thus a dog at
  BCS 4 can fall within the usual ideal range even though PNA's automatic
  calculator does not support it. Do not label it underweight merely because
  PNA declines calculation. Cat BCS 4 receives special lean-patient handling in
  PNA's algorithm; its target estimate is not a general underweight formula.
- PNA's page calls BCS ≥7 obese and recommends a professionally supervised
  weight-loss plan. Label this as the PNA threshold; some other BCS systems
  reserve “obese” for scores 8–9.
- An optional clinician-documented target should be explicitly distinguished
  from a calculated estimate. It does not justify an automatic gain regimen in
  cases excluded by PNA. Current-weight RER remains descriptive, not a feeding order.
- PNA advises monitoring and adjustment, with suggested weekly loss of 1–2% for
  dogs and 0.5–1% for cats. It warns that a 20% reduction may require a therapeutic
  weight-loss diet to avoid nutrient inadequacy. Treats are part of total intake.
- PNA's educational PDF uses dog adult factors 1.6 (neutered) and 1.8 (intact),
  whereas this calculator bundle uses 1.4 and 1.6. These are different starting
  methods. Do not describe the app's calculator factors as the sole PNA standard.

## Additional primary references

- PNA, *Calculating Calories Based on Pet Needs* (RER, alternate MER factors,
  individual variation and use of current intake):
  https://petnutritionalliance.org/wp-content/uploads/2023/03/MER.RER_.PNA_.pdf
- *2021 AAHA Nutrition and Weight Management Guidelines* (BCS assessment,
  individual plans and nutritional risk thresholds):
  https://www.aaha.org/wp-content/uploads/globalassets/02-guidelines/2021-nutrition-and-weight-management/resourcepdfs/new-2021-aaha-nutrition-and-weight-management-guidelines-with-ref.pdf
- WSAVA, *Body Condition Score—Dog* (physical BCS assessment):
  https://wsava.org/wp-content/uploads/2020/01/Body-Condition-Score-Dog.pdf
