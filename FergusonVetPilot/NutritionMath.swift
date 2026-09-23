import Foundation

enum NutritionGoal: String, Equatable {
    case gain = "Gain weight"
    case maintain = "Maintain weight"
    case lose = "Lose weight"
}

enum NutritionWeightUnit: String, CaseIterable, Identifiable {
    case lb
    case kg

    var id: String { rawValue }

    // PNA uses 2.205 lb/kg. This convention is confined to nutrition;
    // medication and other clinical conversions must remain unchanged.
    func kilograms(_ entered: Double) -> Double { self == .lb ? entered / 2.205 : entered }
    func value(fromKg kilograms: Double) -> Double { self == .lb ? kilograms * 2.205 : kilograms }
}

enum NutritionReproductiveStatus: String, CaseIterable, Identifiable {
    case spayedNeutered = "Spayed / Neutered"
    case intact = "Intact"

    var id: String { rawValue }
}

struct NutritionEstimate: Equatable {
    let species: Species
    let bcs: Int
    let goal: NutritionGoal
    let currentKg: Double
    let estimatedIdealKg: Double?
    let clinicianTargetKg: Double?
    let currentRER: Double
    let planningRER: Double?
    let targetCalories: Double?
    let calorieFloor: Double?
    let baselineCalories: Double?
    let reductionPercent: Int
    let factorDescription: String
    let caution: String
    let reproductiveStatus: NutritionReproductiveStatus

    // Weight alone cannot establish body condition. This describes the
    // clinician-selected 9-point BCS, including PNA's BCS >= 7 obesity flag.
    var weightStatus: String {
        switch bcs {
        case 1...3: return "Underweight"
        case 4...5: return "Ideal range"
        case 6: return "Overweight"
        default: return "Obese (PNA)"
        }
    }
}

enum NutritionMath {
    // Operational input bounds, not clinical eligibility criteria.
    static func validWeight(_ kg: Double) -> Bool { kg.isFinite && kg > 0 && kg <= 1000 }

    /// Resting Energy Requirement (RER): 70 × body weight (kg)^0.75.
    static func rer(kg: Double) -> Double {
        guard validWeight(kg) else { return .nan }
        return 70 * pow(kg, 0.75)
    }

    /// Independently implemented from PNA's public calculator behavior,
    /// checked 2026-09-23: https://petnutritionalliance.org/resources/calorie-calculator/
    /// PNA rounds derived ideal weight in the entered unit before converting
    /// pounds to kg, and rounds the estimated baseline before any reduction.
    /// These ordering details can change the final whole-calorie result.
    static func estimate(
        species: Species,
        weight: Double,
        unit: NutritionWeightUnit,
        bcs: Int,
        reproductiveStatus: NutritionReproductiveStatus,
        currentCalories: Double? = nil,
        clinicianTargetWeight: Double? = nil
    ) -> NutritionEstimate? {
        let currentKg = unit.kilograms(weight)
        guard validWeight(currentKg), (1...9).contains(bcs) else { return nil }
        if let calories = currentCalories {
            guard calories.isFinite, calories > 0, calories <= 1_000_000 else { return nil }
        }
        let clinicianTargetKg = clinicianTargetWeight.map { unit.kilograms($0) }
        if let targetKg = clinicianTargetKg {
            guard validWeight(targetKg) else { return nil }
        }

        let currentRER = rer(kg: currentKg)
        let goal: NutritionGoal = bcs <= 3 ? .gain : (bcs >= 6 ? .lose : .maintain)
        let supportedBCS = species == .dog ? bcs >= 5 : bcs >= 4

        func result(
            idealKg: Double? = nil,
            planningRER: Double? = nil,
            targetCalories: Double? = nil,
            calorieFloor: Double? = nil,
            baselineCalories: Double? = nil,
            reductionPercent: Int = 0,
            factorDescription: String,
            caution: String
        ) -> NutritionEstimate {
            NutritionEstimate(
                species: species,
                bcs: bcs,
                goal: goal,
                currentKg: currentKg,
                estimatedIdealKg: idealKg,
                clinicianTargetKg: clinicianTargetKg,
                currentRER: currentRER,
                planningRER: planningRER,
                targetCalories: targetCalories,
                calorieFloor: calorieFloor,
                baselineCalories: baselineCalories,
                reductionPercent: reductionPercent,
                factorDescription: factorDescription,
                caution: caution,
                reproductiveStatus: reproductiveStatus
            )
        }

        guard supportedBCS else {
            let excluded = species == .dog ? "dogs below BCS 4.5/9" : "cats below BCS 4/9"
            let caution = bcs == 4
                ? "BCS 4/9 lies in the ideal body-condition range but is outside PNA's automatic dog calculator. Use a clinician-assessed target weight and nutrition plan. Any target-weight RER shown is a reference calculation, not a feeding prescription."
                : "Use a clinician-assessed target weight and individualized nutrition plan. Any target-weight RER shown is a reference calculation, not a feeding prescription. Investigate low body condition and consider refeeding risk before increasing intake."
            return result(
                planningRER: clinicianTargetKg.map { rer(kg: $0) },
                factorDescription: "PNA does not provide an automatic calorie plan for \(excluded).",
                caution: caution
            )
        }

        let idealInEnteredUnit: Double
        if species == .cat && bcs == 4 {
            idealInEnteredUnit = (weight * 1.05 * 10).rounded() / 10
        } else if bcs == 5 {
            idealInEnteredUnit = weight
        } else {
            idealInEnteredUnit = (weight / (1 + Double(bcs - 5) / 10) * 10).rounded() / 10
        }
        let idealKg = unit.kilograms(idealInEnteredUnit)
        guard validWeight(idealKg) else {
            return result(
                factorDescription: "No automatic calorie result is available for this weight.",
                caution: "The derived ideal weight is outside the calculator's supported range after rounding. Confirm the entered weight and units and use an individualized nutrition plan."
            )
        }

        let idealRER = rer(kg: idealKg)
        let calorieFloor = (0.6 * idealRER).rounded()
        let maintenanceFactor: Double
        if bcs == 5 {
            switch (species, reproductiveStatus) {
            case (.dog, .spayedNeutered): maintenanceFactor = 1.4
            case (.dog, .intact): maintenanceFactor = 1.6
            case (.cat, .spayedNeutered): maintenanceFactor = 1.2
            case (.cat, .intact): maintenanceFactor = 1.4
            }
        } else {
            maintenanceFactor = 1
        }
        let baseline = currentCalories ?? (idealRER * maintenanceFactor).rounded()
        let reduction = bcs >= 7 ? 20 : (bcs == 6 ? 10 : 0)
        let retainedFraction = 1 - Double(reduction) / 100
        let recommended = (baseline * retainedFraction).rounded()
        let baselineDescription = currentCalories != nil
            ? "Baseline = entered current daily calories"
            : "Baseline = round(\(String(format: "%.1f", maintenanceFactor)) × ideal-weight RER)"
        let factorDescription = baselineDescription
            + "; recommended calories = round(baseline × \(String(format: "%.1f", retainedFraction)))."

        guard recommended > 0, recommended >= calorieFloor else {
            return result(
                idealKg: idealKg,
                planningRER: idealRER,
                calorieFloor: calorieFloor,
                baselineCalories: baseline,
                reductionPercent: reduction,
                factorDescription: factorDescription,
                caution: recommended <= 0
                    ? "The calculation rounds to zero calories. Confirm weight, units, and current intake; use an individualized nutrition plan. No automatic feeding amount is provided."
                    : "The calculated recommendation falls below PNA's floor of 60% of ideal-weight RER, rounded to whole calories. No automatic feeding amount is provided; confirm current intake and seek individualized nutritional care."
            )
        }

        var caution = "Starting estimate for adult dogs and cats. Recheck weight, body condition, intake, and clinical response and adjust the plan with the veterinarian."
        if bcs >= 7 {
            caution += " A 20% reduction can compromise nutrient intake from a maintenance diet; a therapeutic weight-loss diet may be needed."
        }
        if species == .cat && bcs >= 6 {
            caution += " Avoid abrupt or severe calorie restriction in cats and monitor food intake closely."
        }
        if species == .cat && bcs == 4 {
            caution += " PNA estimates ideal weight at 105% of current weight for a cat at BCS 4/9."
        }
        return result(
            idealKg: idealKg,
            planningRER: idealRER,
            targetCalories: recommended,
            calorieFloor: calorieFloor,
            baselineCalories: baseline,
            reductionPercent: reduction,
            factorDescription: factorDescription,
            caution: caution
        )
    }
}
