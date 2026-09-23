import SwiftUI

struct NutritionView: View {
    private enum WeightUnit: String, CaseIterable, Identifiable {
        case lb = "lb"
        case kg = "kg"
        var id: String { rawValue }
    }

    @State private var species: Species = .dog
    @State private var weightText = ""
    @State private var unit: WeightUnit = .lb
    @State private var bcs = 5
    @FocusState private var weightFocused: Bool

    private let bcsColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private var weightKg: Double? {
        guard let entered = MedicationSafety.parsePositive(weightText), entered > 0 else { return nil }
        let kg = unit == .kg ? entered : ClinicalData.lbToKg(entered)
        return NutritionMath.validWeight(kg) ? kg : nil
    }

    private var estimate: NutritionEstimate? {
        guard let weightKg else { return nil }
        return NutritionMath.estimate(species: species, currentKg: weightKg, bcs: bcs)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Nutrition & weight plan")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.blue)
                        Text("BCS-based daily calorie starting estimates for adult dogs and cats, inspired by veterinary nutrition calorie-counter workflows.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Patient")
                            .font(.headline)
                            .foregroundStyle(AppTheme.blue)

                        Picker("Species", selection: $species) {
                            ForEach(Species.allCases) { value in
                                Text(value.rawValue).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack(spacing: 10) {
                            TextField("Weight", text: $weightText)
                                .focused($weightFocused)
                                .accessibilityIdentifier("nutrition.weight")
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)

                            Picker("Weight unit", selection: $unit) {
                                ForEach(WeightUnit.allCases) { value in
                                    Text(value.rawValue).tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }
                    }
                    .vetCard()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Body condition score")
                                .font(.headline)
                                .foregroundStyle(AppTheme.blue)
                            Spacer()
                            Text("\(bcs)/9")
                                .font(.headline.monospacedDigit())
                        }

                        LazyVGrid(columns: bcsColumns, spacing: 8) {
                            ForEach(1...9, id: \.self) { score in
                                Button {
                                    bcs = score
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("\(score)")
                                            .font(.headline)
                                        Text(shortBCSLabel(score))
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(
                                        score == bcs ? AppTheme.blue : Color.white,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .foregroundStyle(score == bcs ? Color.white : AppTheme.blue)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(AppTheme.blue.opacity(0.25), lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("nutrition.bcs.\(score)")
                            }
                        }

                        Text(bcsDescription(species: species, score: bcs))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .vetCard()

                    if let estimate {
                        resultCard(estimate)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Enter a valid weight to calculate calories", systemImage: "info.circle.fill")
                                .font(.headline)
                                .foregroundStyle(AppTheme.blue)
                            Text("Enter a positive weight up to 1,000 kg (software input limit), then select the patient's 1–9 body condition score. Use a decimal point; grouped/comma numbers are not accepted.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .vetCard()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Calculation notes")
                            .font(.headline)
                            .foregroundStyle(AppTheme.blue)
                        Text("RER = 70 × body weight (kg)^0.75. BCS 4–5/9 is treated as ideal; BCS 6–9 uses estimated ideal body weight plus species-specific weight-loss factors. For BCS 1–3, VetPilot does not infer ideal weight from BCS alone; it uses a monitored species-specific starting range from current-weight RER.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Reference basis: AAHA Nutrition & Weight Management guidance and the WSAVA 9-point BCS framework. Clinical support only — calorie equations are starting points and should be adjusted from measured response, diet history, activity, life stage, muscle condition, and medical status.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .vetCard()
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { weightFocused = false }.accessibilityIdentifier("nutrition.keyboard.done")
                }
            }
            .navigationBarHidden(true)
        }
    }

    @ViewBuilder
    private func resultCard(_ estimate: NutritionEstimate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(estimate.goal.rawValue, systemImage: goalIcon(estimate.goal))
                    .font(.headline)
                    .foregroundStyle(AppTheme.blue)
                Spacer()
                Text("BCS \(estimate.bcs)/9")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Recommended starting calories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(formatCalories(estimate.targetCalories)) kcal/day")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.orange)
            }

            if abs(estimate.lowCalories - estimate.highCalories) > 0.5 {
                Text("Planning range: \(formatCalories(estimate.lowCalories))–\(formatCalories(estimate.highCalories)) kcal/day")
                    .font(.subheadline.bold())
            }

            Divider()

            if let idealKg = estimate.estimatedIdealKg {
                resultRow("Estimated ideal weight", "~\(formatWeight(idealKg)) kg / ~\(formatWeight(ClinicalData.kgToLb(idealKg))) lb")
            } else {
                resultRow("Target/ideal weight", "Use documented clinical target")
            }
            resultRow("Current-weight RER", "\(formatCalories(estimate.currentRER)) kcal/day")
            resultRow("Planning RER", "\(formatCalories(estimate.planningRER)) kcal/day")

            Text(estimate.factorDescription)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)

            Text(estimate.caution)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .vetCard()
    }

    private func resultRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .multilineTextAlignment(.trailing)
        }
    }

    private func shortBCSLabel(_ score: Int) -> String {
        switch score {
        case 1...2: return "Very thin"
        case 3: return "Thin"
        case 4: return "Ideal"
        case 5: return "Ideal"
        case 6: return "Heavy"
        case 7: return "Over"
        default: return "Obese"
        }
    }

    private func bcsDescription(species: Species, score: Int) -> String {
        let patient = species == .dog ? "dog" : "cat"
        switch score {
        case 1:
            return "Very underconditioned \(patient): prominent bony landmarks with little to no palpable fat."
        case 2:
            return "Markedly underconditioned \(patient): ribs and other bony landmarks are readily visible or palpable."
        case 3:
            return "Underconditioned \(patient): ribs are easy to feel with minimal fat cover and a pronounced waist."
        case 4:
            return "Ideal body condition for many \(patient)s: ribs are easy to feel with minimal fat cover, with a visible waist and abdominal tuck."
        case 5:
            return "Ideal body condition: ribs are palpable without excess fat, with an appropriate waist and abdominal contour."
        case 6:
            return "Slightly above ideal: ribs remain palpable but have mild excess fat cover and the waist is less distinct."
        case 7:
            return "Overweight: ribs are harder to feel, waist definition is reduced, and fat deposits are more apparent."
        case 8:
            return "Markedly overweight: ribs require significant pressure to palpate and the waist/abdominal tuck is minimal or absent."
        default:
            return "Severely above ideal body condition: heavy fat deposits with absent waist and abdominal tuck."
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
        value.isFinite ? String(format: "%.0f", value) : "Invalid value"
    }

    private func formatWeight(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.0001 {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }
}
