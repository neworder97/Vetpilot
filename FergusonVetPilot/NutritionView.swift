import SwiftUI

struct NutritionView: View {
    private enum Field: Hashable { case weight, calories, target }
    @State private var species: Species = .dog
    @State private var weightText = ""
    @State private var unit: NutritionWeightUnit = .lb
    @State private var bcs = 5
    @State private var reproductiveStatus: NutritionReproductiveStatus = .spayedNeutered
    @State private var caloriesText = ""
    @State private var targetText = ""
    @FocusState private var focusedField: Field?

    private let bcsColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private var needsClinicalTarget: Bool { bcs < (species == .dog ? 5 : 4) }
    private var hasCalories: Bool { !caloriesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var hasTarget: Bool { needsClinicalTarget && !targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var weightValid: Bool {
        guard let value = MedicationSafety.parsePositive(weightText) else { return false }
        return NutritionMath.validWeight(unit.kilograms(value))
    }
    private var estimate: NutritionEstimate? {
        guard let weight = MedicationSafety.parsePositive(weightText) else { return nil }
        let calories = hasCalories ? MedicationSafety.parsePositive(caloriesText) : nil
        let target = hasTarget ? MedicationSafety.parsePositive(targetText) : nil
        guard !hasCalories || calories != nil, !hasTarget || target != nil else { return nil }
        return NutritionMath.estimate(species: species, weight: weight, unit: unit, bcs: bcs,
                                      reproductiveStatus: reproductiveStatus,
                                      currentCalories: calories, clinicianTargetWeight: target)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Nutrition & weight plan")
                            .font(.title2.bold()).foregroundStyle(AppTheme.blue)
                        Text("PNA calculator method · Adult dogs and cats")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("Starting estimates for veterinary review. Growing, pregnant, lactating, ill or severely underweight patients need an individualized plan.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Patient").font(.headline).foregroundStyle(AppTheme.blue)
                        Picker("Species", selection: $species) {
                            ForEach(Species.allCases) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)
                        Text("Current weight").font(.subheadline.bold())
                        HStack(spacing: 10) {
                            TextField("Weight", text: $weightText)
                                .focused($focusedField, equals: .weight)
                                .accessibilityIdentifier("nutrition.weight")
                                .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                            Picker("Weight unit", selection: $unit) {
                                ForEach(NutritionWeightUnit.allCases) { Text($0.rawValue).tag($0) }
                            }.pickerStyle(.segmented).frame(width: 120)
                        }
                        Text("Reproductive status").font(.subheadline.bold())
                        Picker("Reproductive status", selection: $reproductiveStatus) {
                            ForEach(NutritionReproductiveStatus.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("nutrition.reproductiveStatus")
                    }.vetCard()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Body condition score").font(.headline).foregroundStyle(AppTheme.blue)
                            Spacer()
                            Text("\(bcs)/9").font(.headline.monospacedDigit())
                        }
                        Text("Assess ribs, waist and fat cover. Weight alone cannot identify underweight or obesity.")
                            .font(.caption).foregroundStyle(.secondary)
                        LazyVGrid(columns: bcsColumns, spacing: 8) {
                            ForEach(1...9, id: \.self) { score in
                                Button { bcs = score; focusedField = nil } label: {
                                    VStack(spacing: 2) {
                                        Text("\(score)").font(.headline)
                                        Text(shortBCSLabel(score)).font(.caption2).lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                                    .background(score == bcs ? AppTheme.blue : Color.white,
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .foregroundStyle(score == bcs ? Color.white : AppTheme.blue)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(AppTheme.blue.opacity(0.25), lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("nutrition.bcs.\(score)")
                                .accessibilityAddTraits(score == bcs ? .isSelected : [])
                            }
                        }
                        Text(bcsDescription).font(.footnote).foregroundStyle(.secondary)
                    }.vetCard()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Current daily calories (optional)").font(.headline).foregroundStyle(AppTheme.blue)
                        TextField("kcal/day — leave blank if unknown", text: $caloriesText)
                            .focused($focusedField, equals: .calories)
                            .accessibilityIdentifier("nutrition.currentCalories")
                            .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                        Text("Include all food, treats and extras. When entered, PNA uses this intake as the starting point; otherwise it estimates from ideal-weight RER.")
                            .font(.caption).foregroundStyle(.secondary)
                        if needsClinicalTarget {
                            Text("Clinician-documented target (optional)").font(.subheadline.bold())
                            TextField("Target weight in \(unit.rawValue)", text: $targetText)
                                .focused($focusedField, equals: .target)
                                .accessibilityIdentifier("nutrition.clinicianTarget")
                                .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                            Text("Use a documented healthy weight or an examined patient's clinical target. This records a target and its RER; it does not create a weight-gain prescription.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.vetCard()

                    if let estimate {
                        resultCard(estimate)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(weightValid ? "Check the optional inputs" : "Enter a valid weight to calculate calories", systemImage: "info.circle.fill")
                                .font(.headline).foregroundStyle(AppTheme.blue)
                                .accessibilityIdentifier("nutrition.input.error")
                            Text("Use positive numbers with a decimal point and no commas. Weight must be at most 1,000 kg; optional intake must be at most 1,000,000 kcal/day (software limits). Clear an optional field if unknown.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }.vetCard()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calculation notes").font(.headline).foregroundStyle(AppTheme.blue)
                        Text("RER = 70 × weight (kg)^0.75. PNA maintenance factors at BCS 5/9: dogs 1.4 spayed/neutered or 1.6 intact; cats 1.2 or 1.4. At BCS 6, reduce the baseline by 10%; at BCS 7–9, reduce it by 20%. Known current intake replaces the estimated baseline.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("For BCS 6–9: estimated ideal weight = current weight ÷ [1 + 0.1 × (BCS − 5)]. PNA rounds this to 0.1 in the selected unit before calculating calories; its lb conversion uses 2.205 lb/kg. Estimated baselines and final calories round to whole kcal. Switching units can cause a small rounding difference.")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("BCS 4–5 is the general ideal range. PNA handles BCS 4 differently: cats use a target 5% above current weight; dogs require a clinical plan. BCS 1–3 has no automatic PNA calorie or ideal-weight estimate. 'Obese (PNA)' follows PNA's BCS ≥7 guidance.")
                            .font(.caption).foregroundStyle(.secondary)
                        Link("Open Pet Nutrition Alliance calculator", destination: URL(string: "https://petnutritionalliance.org/resources/calorie-calculator/?type=\(species == .dog ? "dogs" : "cats")")!)
                            .font(.footnote)
                        Link("AAHA body-condition assessment reference", destination: URL(string: "https://www.aaha.org/resources/2021-aaha-nutrition-and-weight-management-guidelines/screening-evaluation/")!)
                            .font(.footnote)
                        Text("Method checked September 23, 2026. PNA may revise its calculator. Monitor weight, BCS, muscle condition and intake; adjust with the veterinary team. Total daily calories include treats.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.vetCard()
                }.padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: unit) { oldUnit, newUnit in
                // Preserve the patient weight when the display unit changes.
                if let value = MedicationSafety.parsePositive(weightText) {
                    weightText = MedicationSafety.input(newUnit.value(fromKg: oldUnit.kilograms(value)))
                }
                if let value = MedicationSafety.parsePositive(targetText) {
                    targetText = MedicationSafety.input(newUnit.value(fromKg: oldUnit.kilograms(value)))
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }.accessibilityIdentifier("nutrition.keyboard.done")
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func resultCard(_ estimate: NutritionEstimate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(estimate.weightStatus).font(.title3.bold()).foregroundStyle(AppTheme.blue)
                .accessibilityIdentifier("nutrition.result.status")
            HStack {
                Label(estimate.goal.rawValue, systemImage: goalIcon(estimate.goal)).font(.headline)
                Spacer()
                Text("BCS \(estimate.bcs)/9").font(.caption.bold())
            }
            resultRow("Current weight", weightPair(estimate.currentKg), id: "nutrition.result.weight")
            if let ideal = estimate.estimatedIdealKg {
                resultRow("Estimated ideal weight", "~" + weightPair(ideal), id: "nutrition.result.idealWeight")
            } else {
                Text("Ideal weight requires a clinician's assessment.")
                    .font(.subheadline.bold()).accessibilityIdentifier("nutrition.result.idealUnavailable")
            }
            if let target = estimate.clinicianTargetKg {
                resultRow("Clinician-documented target", weightPair(target), id: "nutrition.result.clinicianTarget")
            }
            Divider()
            if let calories = estimate.targetCalories {
                Text("Recommended starting calories").font(.caption).foregroundStyle(.secondary)
                Text("\(formatCalories(calories)) kcal/day")
                    .font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.orange)
                    .accessibilityIdentifier("nutrition.result.calories")
            } else {
                Text("Individual nutrition plan required").font(.headline).foregroundStyle(AppTheme.orange)
                    .accessibilityIdentifier("nutrition.result.unavailable")
            }
            resultRow("Reproductive status", reproductiveStatus.rawValue)
            resultRow("Current-weight RER", "\(formatCalories(estimate.currentRER)) kcal/day")
            if let rer = estimate.planningRER {
                resultRow(estimate.estimatedIdealKg == nil ? "Clinical target RER" : "Ideal-weight RER", "\(formatCalories(rer)) kcal/day")
            }
            if let baseline = estimate.baselineCalories {
                resultRow(hasCalories ? "Entered current intake" : "Estimated calorie baseline", "\(hasCalories ? MedicationSafety.display(baseline) : formatCalories(baseline)) kcal/day")
                resultRow("PNA calorie reduction", "\(estimate.reductionPercent)%")
            }
            Text(estimate.factorDescription).font(.footnote.monospaced()).foregroundStyle(.secondary)
            Text(estimate.caution).font(.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("nutrition.result.caution")
        }.vetCard()
    }

    private func resultRow(_ title: String, _ value: String, id: String = "") -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.bold().monospacedDigit()).multilineTextAlignment(.trailing)
                .accessibilityIdentifier(id)
        }
    }
    private func weightPair(_ kg: Double) -> String {
        let other: NutritionWeightUnit = unit == .kg ? .lb : .kg
        return "\(formatWeight(unit.value(fromKg: kg))) \(unit.rawValue) / \(formatWeight(other.value(fromKg: kg))) \(other.rawValue)"
    }
    private func shortBCSLabel(_ score: Int) -> String {
        switch score {
        case 1...2: return "Very thin"
        case 3: return "Thin"
        case 4...5: return "Ideal range"
        case 6: return "Overweight"
        default: return "Obese (PNA)"
        }
    }
    private var bcsDescription: String {
        switch bcs {
        case 1: return "Severely underweight: prominent bony landmarks and little to no palpable fat. Assess underlying illness and refeeding risk."
        case 2: return "Markedly underweight: ribs and other bony landmarks are readily visible or palpable. Assess muscle loss and refeeding risk."
        case 3: return "Underweight: ribs have minimal fat cover and the waist is pronounced. A clinical target is needed."
        case 4: return "Lean end of the ideal range: ribs are easy to feel with little fat, with a waist and abdominal tuck. PNA uses a special rule for cats and does not calculate for dogs at this score."
        case 5: return "Ideal body condition: ribs are palpable without excess fat, with an appropriate waist and abdominal contour."
        case 6: return "Overweight: mild excess fat over the ribs and less waist definition."
        case 7: return "Obese by PNA's calculator guidance: ribs are harder to feel and fat deposits are more apparent. Use a supervised weight-loss plan."
        case 8: return "Obese: ribs require significant pressure to feel, with minimal or absent waist and abdominal tuck."
        default: return "Severely obese: heavy fat deposits and no visible waist or abdominal tuck. BCS-based ideal weight may underestimate excess fat."
        }
    }
    private func goalIcon(_ goal: NutritionGoal) -> String {
        switch goal {
        case .gain: return "arrow.up.circle.fill"
        case .maintain: return "equal.circle.fill"
        case .lose: return "arrow.down.circle.fill"
        }
    }
    private func formatCalories(_ value: Double) -> String {
        value.isFinite ? String(format: "%.0f", value) : "Unavailable"
    }
    private func formatWeight(_ value: Double) -> String {
        // Keep small adult weights visible, without printing false zeroes.
        String(format: "%.4g", value)
    }
}
