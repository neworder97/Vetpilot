import Foundation

enum NutritionGoal: String, Equatable {
    case gain = "Gain weight"
    case maintain = "Maintain weight"
    case lose = "Lose weight"
}

struct NutritionEstimate: Equatable {
    let species: Species
    let bcs: Int
    let goal: NutritionGoal
    let currentKg: Double
    let estimatedIdealKg: Double?
    let currentRER: Double
    let planningRER: Double
    let targetCalories: Double
    let lowCalories: Double
    let highCalories: Double
    let factorDescription: String
    let caution: String
}

enum NutritionMath {
    /// Resting Energy Requirement (RER): 70 × body weight (kg)^0.75.
    static func rer(kg: Double) -> Double {
        guard kg > 0, kg.isFinite else { return .nan }
        return 70 * pow(kg, 0.75)
    }

    /// BCS-based estimated ideal weight for overweight/obese planning.
    ///
    /// AAHA notes that each whole score above 5/9 is approximately 10%
    /// excess body weight. For underweight patients we intentionally do not
    /// infer an ideal weight from BCS alone because no equally validated
    /// inverse rule exists; a documented prior ideal weight is preferred.
    static func estimatedIdealWeight(currentKg: Double, bcs: Int) -> Double? {
        guard currentKg > 0, currentKg.isFinite, (1...9).contains(bcs) else { return nil }
        if bcs == 4 || bcs == 5 { return currentKg }
        guard bcs >= 6 else { return nil }
        let excessFraction = Double(bcs - 5) * 0.10
        return currentKg / (1 + excessFraction)
    }

    static func estimate(species: Species, currentKg: Double, bcs: Int) -> NutritionEstimate? {
        guard currentKg > 0, currentKg.isFinite, (1...9).contains(bcs) else { return nil }
        let currentRER = rer(kg: currentKg)
        guard currentRER.isFinite else { return nil }

        if bcs >= 6 {
            guard let idealKg = estimatedIdealWeight(currentKg: currentKg, bcs: bcs) else { return nil }
            let planningRER = rer(kg: idealKg)
            let factor = species == .dog ? 1.0 : 0.8
            let target = planningRER * factor
            let felineCaution = species == .cat
                ? " Cats should not undergo abrupt or severe calorie restriction; monitor intake, body weight, and clinical status closely."
                : ""
            return NutritionEstimate(
                species: species,
                bcs: bcs,
                goal: .lose,
                currentKg: currentKg,
                estimatedIdealKg: idealKg,
                currentRER: currentRER,
                planningRER: planningRER,
                targetCalories: target,
                lowCalories: target,
                highCalories: target,
                factorDescription: species == .dog
                    ? "Weight-loss start: 1.0 × RER at estimated ideal weight"
                    : "Weight-loss start: 0.8 × RER at estimated ideal weight",
                caution: "Starting estimate only. Recheck body weight and BCS and adjust to the individual patient's response." + felineCaution
            )
        }

        if bcs == 4 || bcs == 5 {
            let factors: (low: Double, high: Double) = species == .dog ? (1.4, 1.6) : (1.2, 1.4)
            let low = currentRER * factors.low
            let high = currentRER * factors.high
            let target = (low + high) / 2
            return NutritionEstimate(
                species: species,
                bcs: bcs,
                goal: .maintain,
                currentKg: currentKg,
                estimatedIdealKg: currentKg,
                currentRER: currentRER,
                planningRER: currentRER,
                targetCalories: target,
                lowCalories: low,
                highCalories: high,
                factorDescription: species == .dog
                    ? "Adult maintenance start: 1.4–1.6 × RER"
                    : "Adult maintenance start: 1.2–1.4 × RER",
                caution: "This adult maintenance range is a starting estimate. Activity, neuter status, age, disease, environment, and individual metabolism can change calorie needs."
            )
        }

        // There is no single validated BCS-to-ideal-weight inverse rule or
        // universal weight-gain multiplier for underweight adult patients.
        // Use a higher adult energy range from current-weight RER as a
        // conservative monitored starting point, then titrate to response.
        let factors: (low: Double, high: Double) = species == .dog ? (1.6, 1.8) : (1.4, 1.6)
        let low = currentRER * factors.low
        let high = currentRER * factors.high
        let target = (low + high) / 2
        let severeCaution = bcs <= 2
            ? " Severe underconditioning warrants evaluation for an underlying cause and refeeding risk before advancing calories."
            : ""
        return NutritionEstimate(
            species: species,
            bcs: bcs,
            goal: .gain,
            currentKg: currentKg,
            estimatedIdealKg: nil,
            currentRER: currentRER,
            planningRER: currentRER,
            targetCalories: target,
            lowCalories: low,
            highCalories: high,
            factorDescription: species == .dog
                ? "Weight-gain start: 1.6–1.8 × current-weight RER"
                : "Weight-gain start: 1.4–1.6 × current-weight RER",
            caution: "Monitored starting range only, not a fixed prescription. Investigate unexplained weight loss and reassess body weight, BCS, muscle condition, intake, and tolerance." + severeCaution
        )
    }

}