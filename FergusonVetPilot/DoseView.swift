import SwiftUI

struct DoseView: View {
    private enum DoseField: Hashable { case weight, search }

    @State private var species: Species = .dog
    @State private var weight = ""
    @State private var weightUnit = "lb"
    @State private var form: MedicationForm = .any
    @State private var search = ""
    @State private var selectedMedication: Medication?
    @State private var showCustomMedications = false
    @StateObject private var customStore = CustomMedicationStore()
    @StateObject private var protocolStore = ProtocolMedicationStore()
    @FocusState private var focusedField: DoseField?

    private var medications: [Medication] {
        let builtIn = ClinicalData.searchMedications(query: search, species: species, form: form)
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let custom = customStore.definitions.map(\.asMedication).filter { med in
            guard med.supports(species) else { return false }
            guard form == .any || med.form == form else { return false }
            if needle.isEmpty { return true }
            return [med.generic, med.brand, med.drugClass, med.indication]
                .joined(separator: " ")
                .lowercased()
                .contains(needle)
        }
        return (builtIn + custom).sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Automatic dose calculator")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.blue)
                        Text("Choose a medication, then enter or edit the patient weight inside the dose screen. Automatic math is enabled only for source-backed rules. Veterinarian verification is required before prescribing, dispensing, or administering.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Species", selection: $species) {
                        ForEach(Species.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        TextField("Patient weight (optional here)", text: $weight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .weight)

                        Picker("Unit", selection: $weightUnit) {
                            Text("lb").tag("lb")
                            Text("kg").tag("kg")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                    }

                    Picker("Form", selection: $form) {
                        ForEach(MedicationForm.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search medications…", text: $search)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .search)
                    }
                    .padding(11)
                    .background(AppTheme.pale, in: RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Text("\(medications.count) entries")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            focusedField = nil
                            showCustomMedications = true
                        } label: {
                            Label("Custom", systemImage: "plus.circle.fill")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("dose.custom")
                    }

                    LazyVStack(spacing: 10) {
                        ForEach(medications) { med in
                            Button {
                                focusedField = nil
                                selectedMedication = med
                            } label: {
                                MedicationRow(
                                    medication: med,
                                    clinicOverrideEnabled: med.kind == .protocolOnly && protocolStore.definition(for: med, species: species) != nil,
                                    builtInAvailable: med.kind == .protocolOnly && BuiltInProtocolCatalog.hasPreset(for: med, species: species)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .navigationBarHidden(true)
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showCustomMedications) {
                CustomMedicationManagerView(store: customStore)
            }
            .sheet(item: $selectedMedication) { med in
                DoseCalculatorSheet(
                    medication: med,
                    species: species,
                    protocolStore: protocolStore,
                    weight: Double(weight) ?? 0,
                    weightUnit: weightUnit
                )
            }
        }
    }
}

private struct MedicationRow: View {
    let medication: Medication
    let clinicOverrideEnabled: Bool
    let builtInAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(medication.displayName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.blue)
                Spacer()
                if medication.controlled {
                    Text("CONTROLLED")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.orange)
                }
            }

            Text("\(medication.form.rawValue) • \(medication.drugClass)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(medication.indication)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if medication.source.hasPrefix("CUSTOM-UNVERIFIED") {
                Label("Custom automatic math • unverified", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.orange)
            } else if medication.source.hasPrefix("USER-SOURCE-BACKED") {
                Label("Custom automatic math • user source attached", systemImage: "link.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
            } else if medication.kind == .protocolOnly && clinicOverrideEnabled {
                Label("Clinic override enabled", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.green)
            } else if medication.kind == .protocolOnly && builtInAvailable {
                Label("Preloaded calculator • protocol/indication selector", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.green)
            } else if medication.kind == .protocolOnly {
                Label("Clinic protocol required • tap to enable", systemImage: "book.closed.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)
            } else if medication.source.hasPrefix("MSD Veterinary Manual") {
                Label("Reference-backed automatic calculation", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.green)
            } else {
                Label("Label/source-backed automatic calculation", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vetCard()
    }
}

private struct DoseCalculatorSheet: View {
    private enum FrequencyChoice: String, CaseIterable, Identifiable {
        case recommended = "Recommended"
        case q8h = "q8h"
        case q12h = "q12h"
        case q24h = "q24h"

        var id: String { rawValue }
        var dosesPerDay: Double? {
            switch self {
            case .recommended: return nil
            case .q8h: return 3
            case .q12h: return 2
            case .q24h: return 1
            }
        }
    }
    let medication: Medication
    let species: Species
    @ObservedObject var protocolStore: ProtocolMedicationStore

    @Environment(\.dismiss) private var dismiss
    @State private var patientWeight: String
    @State private var patientWeightUnit: String
    @State private var selectedStrengthIndex = 0
    @State private var concentration = ""
    @State private var result: DoseResult?
    @State private var supplyDays: Int?
    @State private var selectedFrequency: FrequencyChoice = .recommended
    @State private var selectedDoseLevel: DoseSelectionLevel = .middle
    @State private var solidRounding: SolidDoseRounding = .nearest
    @State private var selectedPresetIndex = 0
    @State private var showProtocolEditor = false
    @FocusState private var weightFieldFocused: Bool

    init(medication: Medication, species: Species, protocolStore: ProtocolMedicationStore, weight: Double, weightUnit: String) {
        self.medication = medication
        self.species = species
        self.protocolStore = protocolStore
        _patientWeight = State(initialValue: weight > 0 ? ClinicalData.format(weight) : "")
        _patientWeightUnit = State(initialValue: weightUnit)
    }

    private var numericWeight: Double {
        Double(patientWeight.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var kg: Double {
        patientWeightUnit == "lb" ? ClinicalData.lbToKg(numericWeight) : numericWeight
    }

    private var clinicOverride: ProtocolMedicationDefinition? {
        guard medication.kind == .protocolOnly else { return nil }
        return protocolStore.definition(for: medication, species: species)
    }

    private var builtInPresets: [BuiltInProtocolPreset] {
        guard medication.kind == .protocolOnly else { return [] }
        return BuiltInProtocolCatalog.presets(for: medication, species: species)
    }

    private var selectedBuiltInPreset: BuiltInProtocolPreset? {
        guard clinicOverride == nil,
              !builtInPresets.isEmpty,
              builtInPresets.indices.contains(selectedPresetIndex) else { return nil }
        return builtInPresets[selectedPresetIndex]
    }

    private var protocolDefinition: ProtocolMedicationDefinition? {
        clinicOverride ?? selectedBuiltInPreset?.definition
    }

    private var usingBuiltInPreset: Bool {
        clinicOverride == nil && selectedBuiltInPreset != nil
    }

    private var activeStrengths: [Double] {
        protocolDefinition?.strengths ?? medication.strengths
    }

    private var selectedStrength: Double? {
        guard !activeStrengths.isEmpty,
              activeStrengths.indices.contains(selectedStrengthIndex) else { return nil }
        return activeStrengths[selectedStrengthIndex]
    }

    private var activeConcentration: Double? {
        if let entered = Double(concentration), entered > 0 { return entered }
        return protocolDefinition?.concentration ?? medication.concentration
    }

    private var recommendedFrequency: String {
        protocolDefinition?.frequency ?? medication.frequency
    }

    private var activeRoute: String {
        protocolDefinition?.route ?? medication.route
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(medication.displayName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.blue)
                    Text(medication.indication)
                }

                if medication.kind == .protocolOnly {
                    Section("Medication protocol") {
                        if let clinicOverride {
                            Label("Clinic override enabled for \(species.rawValue)", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Color.green)
                            LabeledContent("Equation", value: clinicOverride.doseBasis.rawValue)
                            if !clinicOverride.frequency.isEmpty {
                                LabeledContent("Frequency", value: clinicOverride.frequency)
                            }
                            if !clinicOverride.route.isEmpty {
                                LabeledContent("Route", value: clinicOverride.route)
                            }
                            Button("Edit clinic override") { showProtocolEditor = true }
                            if !builtInPresets.isEmpty {
                                Button("Disable override and use preloaded protocols", role: .destructive) {
                                    protocolStore.remove(for: medication, species: species)
                                    selectedPresetIndex = 0
                                }
                            }
                        } else if !builtInPresets.isEmpty {
                            Label("Preloaded calculator available", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(Color.green)
                                .accessibilityIdentifier("dose.protocol.preloaded")

                            if builtInPresets.count > 1 {
                                Picker("Protocol / indication", selection: $selectedPresetIndex) {
                                    ForEach(Array(builtInPresets.enumerated()), id: \.element.id) { index, preset in
                                        Text(preset.displayLabel).tag(index)
                                    }
                                }
                                .accessibilityIdentifier("dose.protocol.picker")
                            }

                            if let selectedBuiltInPreset {
                                Text(selectedBuiltInPreset.label)
                                    .font(.footnote.weight(.semibold))
                                LabeledContent("Equation", value: selectedBuiltInPreset.doseBasis.rawValue)
                                if !selectedBuiltInPreset.frequency.isEmpty {
                                    LabeledContent("Frequency", value: selectedBuiltInPreset.frequency)
                                }
                                if !selectedBuiltInPreset.route.isEmpty {
                                    LabeledContent("Route", value: selectedBuiltInPreset.route)
                                }
                                if !selectedBuiltInPreset.confidence.isEmpty {
                                    LabeledContent("Research confidence", value: selectedBuiltInPreset.confidence)
                                }
                                if selectedBuiltInPreset.highRisk {
                                    Text("High-risk/monitored protocol: choose the intended indication/route/product or treatment branch and verify the final plan with the veterinarian before use.")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.orange)
                                }
                            }

                            Button {
                                showProtocolEditor = true
                            } label: {
                                Label("Enter / edit clinic override", systemImage: "slider.horizontal.3")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("dose.protocol.override")
                        } else {
                            Text("No preloaded automatic rule is available for this entry.")
                                .foregroundStyle(.secondary)
                            Button {
                                showProtocolEditor = true
                            } label: {
                                Label("Enable Calculator / Enter Protocol", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("dose.protocol.enable")
                        }
                    }
                }

                Section("Patient weight") {
                    HStack {
                        TextField("Enter weight", text: $patientWeight)
                            .keyboardType(.decimalPad)
                            .focused($weightFieldFocused)
                            .accessibilityIdentifier("dose.sheet.weight")

                        Picker("Unit", selection: $patientWeightUnit) {
                            Text("lb").tag("lb")
                            Text("kg").tag("kg")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 130)
                    }

                    if numericWeight > 0 {
                        Text("\(ClinicalData.format(kg)) kg / \(ClinicalData.format(ClinicalData.kgToLb(kg))) lb")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else if protocolDefinition?.doseBasis.requiresWeight == false {
                        Text("The selected protocol uses a fixed per-patient/eye dose; weight is optional for the arithmetic.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Enter a patient weight to enable automatic calculation.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.orange)
                    }
                }

                if !activeStrengths.isEmpty {
                    Section("Product strength") {
                        Picker("Strength", selection: $selectedStrengthIndex) {
                            ForEach(Array(activeStrengths.enumerated()), id: \.offset) { index, value in
                                Text("\(ClinicalData.format(value)) mg").tag(index)
                            }
                        }
                    }
                }

                let needsProtocolConcentration = protocolDefinition?.doseBasis.supportsConcentration == true
                let needsMedicationConcentration = protocolDefinition == nil && [.liquid, .injection, .transdermal].contains(medication.form)
                let requiredVolumeProtocolConcentration: Double? = {
                    guard protocolDefinition?.doseBasis == .mLKg else { return nil }
                    return protocolDefinition?.concentration
                }()

                if let required = requiredVolumeProtocolConcentration {
                    Section("Required product concentration (mg/mL)") {
                        Text("\(ClinicalData.format(required)) mg/mL")
                            .font(.headline)
                        Text("This preloaded mL/kg protocol applies to this product concentration. Do not substitute a different concentration without selecting or entering the matching veterinarian-approved protocol.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if (needsProtocolConcentration || needsMedicationConcentration) && medication.generic != "Mirtazapine transdermal" {
                    let concentrationUnit = protocolDefinition?.doseBasis.concentrationLabel ?? "mg/mL"
                    Section("Concentration (\(concentrationUnit)) — verify product") {
                        TextField(concentrationUnit, text: $concentration)
                            .keyboardType(.decimalPad)
                        Text("Enter the exact product concentration in \(concentrationUnit).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        if let protocolDefinition {
                            result = ProtocolDoseCalculator.calculate(
                                definition: protocolDefinition,
                                kg: kg,
                                strength: selectedStrength,
                                concentration: activeConcentration,
                                builtInPreset: usingBuiltInPreset ? selectedBuiltInPreset : nil
                            )
                        } else {
                            result = ClinicalData.calculate(
                                medication: medication,
                                kg: kg,
                                strength: selectedStrength,
                                concentration: activeConcentration
                            )
                        }
                        supplyDays = nil
                        selectedFrequency = .recommended
                        selectedDoseLevel = .middle
                        solidRounding = .nearest
                    } label: {
                        Label("Calculate dose", systemImage: "function")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                                        .disabled(((protocolDefinition?.doseBasis.requiresWeight ?? true) && numericWeight <= 0) || (medication.kind == .protocolOnly && protocolDefinition == nil))
                    .accessibilityIdentifier("dose.calculate")
                }

                if let result {
                    Section("Result") {
                        Text(result.headline)
                            .font(.title3.bold())
                            .foregroundStyle(result.available ? AppTheme.blue : AppTheme.orange)

                        if !result.math.isEmpty {
                            LabeledContent("Math", value: result.math)
                        }
                        if !result.formulation.isEmpty {
                            LabeledContent("Formulation", value: result.formulation)
                        }
                        if !result.warning.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Safety").font(.caption.bold()).foregroundStyle(AppTheme.orange)
                                Text(result.warning)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Source").font(.caption.bold())
                            if let preset = selectedBuiltInPreset, usingBuiltInPreset {
                                Text(preset.sourceReference.isEmpty ? "Preloaded veterinary reference protocol" : preset.sourceReference)
                            } else {
                                Text(protocolDefinition.map { $0.sourceReference.isEmpty ? "Clinic-entered protocol • no external source attached" : "Clinic-entered protocol • \($0.sourceReference)" } ?? medication.source)
                            }
                        }

                        LabeledContent("Recommended frequency", value: recommendedFrequency)
                        if !activeRoute.isEmpty { LabeledContent("Route", value: activeRoute) }

                        Text("Veterinarian verification required before prescribing, dispensing, or administering.")
                            .font(.footnote.bold())
                    }

                    if result.available, let selection = doseSelection {
                        Section("Dose range choice") {
                            if selection.hasRange {
                                Picker("Dose level", selection: $selectedDoseLevel) {
                                    ForEach(DoseSelectionLevel.allCases) { level in
                                        Text(level.rawValue).tag(level)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .accessibilityIdentifier("dose.level")

                                doseLevelRow(.low)
                                doseLevelRow(.middle)
                                doseLevelRow(.high)

                                Text("Low, middle, and high are mathematical points within the selected source-backed or veterinarian-entered dose range. VetPilot does not choose which point is clinically appropriate.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                LabeledContent("Selected dose", value: "\(ClinicalData.format(selection.selected)) \(selection.unit)")
                            }
                        }

                        Section("Administration") {
                            LabeledContent("Selected target", value: "\(ClinicalData.format(selection.selected)) \(selection.unit)")
                            Text("\(selection.math) = \(ClinicalData.format(selection.selected)) \(selection.unit)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let solid = selectedSolidPlan {
                                LabeledContent("Raw formulation", value: "\(ClinicalData.format(solid.rawUnits)) \(solidUnitName)")

                                Picker("Whole-unit rounding", selection: $solidRounding) {
                                    ForEach(SolidDoseRounding.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .accessibilityIdentifier("dose.rounding")

                                if solid.roundedUnits > 0 {
                                    Text(administrationInstruction(for: solid))
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.blue)
                                        .accessibilityIdentifier("dose.administration.instruction")
                                    LabeledContent("Delivered drug amount", value: "\(ClinicalData.format(solid.deliveredMg)) mg")
                                    if kg > 0 {
                                        LabeledContent("Delivered mg/kg", value: "\(ClinicalData.format(solid.deliveredMg / kg)) mg/kg")
                                    }
                                    LabeledContent("Difference from selected target", value: varianceText(solid.variancePercent))
                                } else {
                                    Text("This rounding choice produces 0 whole units. Choose a different strength or rounding direction; VetPilot will not force a non-zero dose because that could overshoot the selected target.")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.orange)
                                }

                                Text("Whole-unit rounding is shown explicitly. VetPilot does not assume a tablet is scored/splittable and never splits capsules automatically. If a veterinarian authorizes tablet splitting, use an appropriate strength or clinic-entered protocol and verify the final dose.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let volume = selectedAdministrationVolume {
                                Text(volumeInstruction(volume))
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.blue)
                                    .accessibilityIdentifier("dose.administration.instruction")
                                if let c = activeConcentration, c > 0, protocolDefinition?.doseBasis != .mLKg {
                                    LabeledContent("Verified concentration", value: "\(ClinicalData.format(c)) \(protocolDefinition?.doseBasis.concentrationLabel ?? "mg/mL")")
                                }
                            } else {
                                Text("Use the selected calculated amount above with the verified product/formulation. No automatic unit rounding is applied for this dosage form.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            LabeledContent("Administration frequency", value: activeFrequencyLabel)
                            if !activeRoute.isEmpty { LabeledContent("Route", value: activeRoute) }
                        }
                    }

                    if result.available, (medication.kind != .protocolOnly || protocolDefinition != nil), medication.form != .injection {
                        Section("Optional veterinarian frequency") {
                            Text("Use the source-backed recommended frequency unless the prescribing veterinarian directs a different schedule. Choosing an override changes schedule/supply math only; it does not validate the new frequency or change the calculated per-administration dose.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                frequencyButton(.recommended, title: "Recommended")
                                frequencyButton(.q8h, title: "Every 8 h")
                                frequencyButton(.q12h, title: "Every 12 h")
                                frequencyButton(.q24h, title: "Every 24 h")
                            }

                            HStack {
                                Text("Active schedule")
                                Spacer()
                                Text(activeFrequencyLabel)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("dose.frequency.active")
                            }

                            if selectedFrequency != .recommended {
                                Text("Prescriber override selected. Confirm indication, duration, maximums, and patient-specific risks with the veterinarian before use.")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.orange)
                                    .accessibilityIdentifier("dose.frequency.override.warning")
                            }

                            if selectedFrequency != .recommended, recommendedFrequency.lowercased().contains("total daily dose") {
                                Text("This entry is calculated as a total daily dose. The override changes administration timing only; VetPilot keeps the total daily drug amount unchanged and does not decide how the veterinarian wants that daily total divided.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if result.available, medication.form == .injection {
                        Section("Injectable administration") {
                            Text("Immediate-use injectable: this calculator shows the single administration dose/volume only. No 7-day, 2-week, or 30-day take-home supply counter is available for injectable medications.")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.blue)
                                .accessibilityIdentifier("dose.injectable.single")
                        }
                    }

                    if result.available, canPlanSupply {
                        Section("Quantity dispensed — math only") {
                            HStack {
                                supplyButton(days: 7, title: "7 days")
                                supplyButton(days: 14, title: "2 weeks")
                                supplyButton(days: 30, title: "30 days")
                            }

                            if let days = supplyDays {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(supplySummary(days: days))
                                        .font(.subheadline.weight(.semibold))
                                        .accessibilityIdentifier("dose.supply.summary")
                                    Text("Quantity dispensed uses the selected dose level, selected whole-unit rounding (for tablets/capsules), active schedule, and chosen duration. It does not choose treatment duration or override labeled/protocol maximums. Verify the final prescription and dispense quantity with the veterinarian.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("dose.done")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        weightFieldFocused = false
                    }
                    .accessibilityIdentifier("dose.keyboard.done")
                }
            }
            .onAppear {
                if let c = protocolDefinition?.concentration ?? medication.concentration {
                    concentration = ClinicalData.format(c)
                }
            }
            .onChange(of: patientWeight) { _, _ in
                result = nil
                supplyDays = nil
                selectedFrequency = .recommended
            }
            .onChange(of: patientWeightUnit) { _, _ in
                result = nil
                supplyDays = nil
                selectedFrequency = .recommended
            }
            .onChange(of: selectedStrengthIndex) { _, _ in
                result = nil
                supplyDays = nil
                selectedFrequency = .recommended
            }
            .onChange(of: concentration) { _, _ in
                result = nil
                supplyDays = nil
                selectedFrequency = .recommended
            }
            .sheet(isPresented: $showProtocolEditor) {
                ProtocolMedicationEditorView(
                    medication: medication,
                    species: species,
                    store: protocolStore,
                    seed: selectedBuiltInPreset?.definition
                )
            }
            .onChange(of: selectedDoseLevel) { _, _ in
                supplyDays = nil
            }
            .onChange(of: solidRounding) { _, _ in
                supplyDays = nil
            }
            .onChange(of: selectedPresetIndex) { _, _ in
                result = nil
                supplyDays = nil
                selectedFrequency = .recommended
                selectedStrengthIndex = 0
                if let c = protocolDefinition?.concentration {
                    concentration = ClinicalData.format(c)
                } else if medication.kind == .protocolOnly {
                    concentration = ""
                }
            }
            .onChange(of: protocolStore.definitions) { _, _ in
                result = nil
                selectedStrengthIndex = 0
                if let c = protocolDefinition?.concentration {
                    concentration = ClinicalData.format(c)
                } else if medication.kind == .protocolOnly {
                    concentration = ""
                }
            }
        }
    }

    private var canPlanSupply: Bool {
        dosesPerDay != nil &&
        (medication.kind != .protocolOnly || protocolDefinition != nil) &&
        selectedBuiltInPreset?.highRisk != true &&
        medication.form != .injection
    }

    private var activeFrequencyLabel: String {
        selectedFrequency == .recommended ? recommendedFrequency : selectedFrequency.rawValue
    }

    private var dosesPerDay: Double? {
        if let override = selectedFrequency.dosesPerDay { return override }
        let f = recommendedFrequency.lowercased()
        if f.contains("total daily dose divided into 2") { return 2 }
        if f.contains("q4h") { return 6 }
        if f.contains("q6h") { return 4 }
        if f.contains("q8h") { return 3 }
        if f.contains("q12h") { return 2 }
        if f.contains("q24h") { return 1 }
        if f.contains("q48h") { return 0.5 }
        if f.contains("q72h") { return 1.0 / 3.0 }
        return nil
    }

    private var doseMultiplierPerDay: Double? {
        guard let dosesPerDay else { return nil }
        if recommendedFrequency.lowercased().contains("total daily dose") {
            return 1
        }
        return dosesPerDay
    }

    @ViewBuilder
    private func frequencyButton(_ choice: FrequencyChoice, title: String) -> some View {
        let identifier = "dose.frequency.\(choice == .recommended ? "recommended" : choice.rawValue)"
        if selectedFrequency == choice {
            Button(title) {
                selectedFrequency = choice
                supplyDays = nil
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(identifier)
        } else {
            Button(title) {
                selectedFrequency = choice
                supplyDays = nil
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(identifier)
        }
    }

    @ViewBuilder
    private func supplyButton(days: Int, title: String) -> some View {
        if supplyDays == days {
            Button(title) {
                supplyDays = days
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("dose.supply.\(days)")
        } else {
            Button(title) {
                supplyDays = days
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("dose.supply.\(days)")
        }
    }

    private var doseSelection: DoseRangeSelection? {
        if let protocolDefinition {
            return AdministrationMath.selection(for: protocolDefinition, kg: kg, level: selectedDoseLevel)
        }
        return AdministrationMath.selection(for: medication, kg: kg, level: selectedDoseLevel)
    }

    private func selection(for level: DoseSelectionLevel) -> DoseRangeSelection? {
        if let protocolDefinition {
            return AdministrationMath.selection(for: protocolDefinition, kg: kg, level: level)
        }
        return AdministrationMath.selection(for: medication, kg: kg, level: level)
    }

    @ViewBuilder
    private func doseLevelRow(_ level: DoseSelectionLevel) -> some View {
        if let choice = selection(for: level) {
            HStack {
                Text(level.rawValue)
                Spacer()
                Text("\(ClinicalData.format(choice.selected)) \(choice.unit)")
                    .foregroundStyle(level == selectedDoseLevel ? AppTheme.blue : .secondary)
            }
        }
    }

    private var selectedSolidPlan: SolidAdministrationPlan? {
        guard let selection = doseSelection, selection.unit == "mg", !selection.isRate,
              let strength = selectedStrength, strength > 0,
              [.tablet, .capsule].contains(medication.form), routeSupportsOralSolid else { return nil }
        return AdministrationMath.solidPlan(targetMg: selection.selected, strengthMg: strength, rounding: solidRounding)
    }

    private var routeSupportsOralSolid: Bool {
        let route = activeRoute.uppercased()
        if route.isEmpty { return true }
        let parenteralMarkers = ["IV", "IM", "SC", "CRI", "INFUSION"]
        if parenteralMarkers.contains(where: route.contains) { return false }
        return route.contains("PO") || route.contains("ORAL")
    }

    private var routeSupportsMeasuredVolume: Bool {
        let route = activeRoute.uppercased()
        if medication.form == .liquid || medication.form == .injection || medication.form == .transdermal { return true }
        if ["IV", "IM", "SC", "CRI", "INFUSION"].contains(where: route.contains) { return true }
        return selectedStrength == nil
    }

    private var solidUnitName: String {
        medication.form == .capsule ? "capsule(s)" : "tablet(s)"
    }

    private var selectedAdministrationVolume: (value: Double, unit: String)? {
        guard let selection = doseSelection, routeSupportsMeasuredVolume else { return nil }
        return AdministrationMath.volume(
            selection: selection,
            basis: protocolDefinition?.doseBasis,
            concentration: activeConcentration
        )
    }

    private func administrationInstruction(for solid: SolidAdministrationPlan) -> String {
        let qty = ClinicalData.format(solid.roundedUnits)
        if recommendedFrequency.lowercased().contains("total daily dose") && selectedFrequency == .recommended {
            return "Daily total: \(qty) \(solidUnitName); divide across the recommended administrations exactly as directed by the veterinarian."
        }
        return "Give \(qty) \(solidUnitName) \(activeFrequencyLabel)."
    }

    private func volumeInstruction(_ volume: (value: Double, unit: String)) -> String {
        let amount = ClinicalData.format(volume.value)
        if volume.unit == "mL/hr" {
            return "Set calculated rate: \(amount) mL/hr."
        }
        if volume.unit.contains("drop") {
            return "Give \(amount) \(volume.unit) \(activeFrequencyLabel)."
        }
        if recommendedFrequency.lowercased().contains("total daily dose") && selectedFrequency == .recommended {
            return "Calculated daily total: \(amount) \(volume.unit); divide across the recommended administrations exactly as directed by the veterinarian."
        }
        return "Give \(amount) \(volume.unit) \(activeFrequencyLabel)."
    }

    private func varianceText(_ percent: Double) -> String {
        if abs(percent) < 0.005 { return "0% (matches target)" }
        let sign = percent > 0 ? "+" : ""
        return "\(sign)\(ClinicalData.format(percent))%"
    }

    private func supplySummary(days: Int) -> String {
        guard let dosesPerDay else {
            return "Quantity dispensed is not available for this frequency. Choose a specific schedule if the recommendation is a range."
        }

        let administrations = AdministrationMath.administrations(days: days, dosesPerDay: dosesPerDay)
        let scheduleText = selectedFrequency == .recommended ? recommendedFrequency : selectedFrequency.rawValue
        let isDailyTotal = recommendedFrequency.lowercased().contains("total daily dose") && selectedFrequency == .recommended

        if medication.kind == .robenacoxibCatBand {
            let tabletsPerDose = kg <= 6 ? 1.0 : 2.0
            let total = tabletsPerDose * Double(administrations)
            return "\(days) days • \(scheduleText) • \(administrations) administration(s) • quantity to dispense: \(ClinicalData.format(total)) × 6 mg tablet(s), before label-duration checks"
        }

        if medication.generic == "Mirtazapine transdermal" && medication.brand == "Mirataz" {
            return "\(days) days • \(scheduleText) • \(administrations) application(s) using the labeled ribbon length per administration"
        }

        if let solid = selectedSolidPlan, solid.roundedUnits > 0 {
            let totalUnits = isDailyTotal
                ? solid.roundedUnits * Double(days)
                : solid.roundedUnits * Double(administrations)
            let dispense = ceil(totalUnits)
            return "\(days) days • \(scheduleText) • \(administrations) administration(s) • \(ClinicalData.format(solid.roundedUnits)) \(solidUnitName) \(isDailyTotal ? "per day total" : "per administration") • quantity to dispense: \(ClinicalData.format(dispense)) \(solidUnitName)"
        }

        if let volume = selectedAdministrationVolume, volume.unit == "mL" {
            let multiplier = isDailyTotal ? Double(days) : Double(administrations)
            let total = volume.value * multiplier
            return "\(days) days • \(scheduleText) • \(administrations) administration(s) • \(ClinicalData.format(volume.value)) mL \(isDailyTotal ? "per day total" : "per administration") • calculated quantity to dispense: \(ClinicalData.format(total)) mL"
        }

        if let selection = doseSelection {
            let multiplier = isDailyTotal ? Double(days) : Double(administrations)
            let total = selection.selected * multiplier
            return "\(days) days • \(scheduleText) • \(administrations) administration(s) • calculated total: \(ClinicalData.format(total)) \(selection.unit)"
        }

        return "\(days) days • \(scheduleText) • \(administrations) administration(s)"
    }

    private func formatRange(_ low: Double, _ high: Double) -> String {
        abs(low - high) < 0.0000001
            ? ClinicalData.format(low)
            : "\(ClinicalData.format(low))–\(ClinicalData.format(high))"
    }
}
