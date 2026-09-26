import SwiftUI

struct DoseView: View {
    private enum DoseField: Hashable { case weight, search }

    @State private var species: Species = .dog
    @State private var weight = ""
    @State private var weightUnit = "lb"
    @State private var form: MedicationForm = .any
    @State private var search = ""
    @State private var catalogGroup = "All medications"
    @State private var selectedMedication: Medication?
    @State private var showCustomMedications = false
    @ObservedObject var customStore: CustomMedicationStore
    @StateObject private var protocolStore = ProtocolMedicationStore()
    @FocusState private var focusedField: DoseField?

    private var medications: [Medication] {
        let builtIn = ClinicalData.searchMedications(query: search, species: species, form: form).filter(matchesCatalogGroup)
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let custom = customStore.definitions.map(\.asMedication).filter { med in
            guard med.supports(species), matchesCatalogGroup(med) else { return false }
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

    private func matchesCatalogGroup(_ medication: Medication) -> Bool {
        switch catalogGroup {
        case "Tablets / capsules": return [.tablet, .capsule].contains(medication.form)
        case "Oral solutions / suspensions": return medication.form == .liquid
        case "Injections": return medication.form == .injection
        case "Other forms": return ![.tablet, .capsule, .liquid, .injection].contains(medication.form)
        default: return true
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

                    DisclosureGroup("Medication catalog · \(catalogGroup)") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                        ForEach(["All medications", "Tablets / capsules", "Oral solutions / suspensions", "Injections", "Other forms"], id: \.self) { category in
                            Button(category) { catalogGroup = category; form = .any; selectedMedication = nil }
                                .buttonStyle(.bordered)
                                .tint(catalogGroup == category ? AppTheme.blue : .secondary)
                                .accessibilityIdentifier("dose.catalog.\(category)")
                                .accessibilityAddTraits(catalogGroup == category ? .isSelected : [])
                        }
                    }
                    }
                    .tint(AppTheme.blue)
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
                            Label("Add medication", systemImage: "plus.circle.fill")
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
                    weight: MedicationSafety.parsePositive(weight) ?? 0,
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
        case q6h = "q6h"
        case q8h = "q8h"
        case q12h = "q12h"
        case q24h = "q24h"

        var id: String { rawValue }
        var dosesPerDay: Double? {
            switch self {
            case .recommended: return nil
            case .q6h: return 4
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
    @State private var infusionConcentrationConfirmed = false
    @State private var prescribedPotassiumRate = ""
    @State private var result: DoseResult?
    @State private var supplyDays: Int?
    @State private var priorCourseDoses = 0
    @State private var priorCourseHistoryConfirmed = false
    @State private var selectedFrequency: FrequencyChoice = .recommended
    @State private var selectedDoseLevel: DoseSelectionLevel = .low
    @State private var recommendationHelp = false
    @State private var prescribedBuprenorphine = false
    @State private var solidRounding: SolidDoseRounding = .nearest
    @State private var selectedPresetIndex = 0
    @State private var showProtocolEditor = false
    @FocusState private var weightFieldFocused: Bool

    init(medication: Medication, species: Species, protocolStore: ProtocolMedicationStore, weight: Double, weightUnit: String) {
        self.medication = medication
        self.species = species
        self.protocolStore = protocolStore
        _patientWeight = State(initialValue: weight > 0 ? MedicationSafety.input(weight) : "")
        _patientWeightUnit = State(initialValue: weightUnit)
    }

    private func calculateCandidate() {
                        if let error = prescribedRateInputError {
                            result = DoseResult(available: false, headline: "Prescribed rate required", math: "", formulation: "", warning: error)
                            return
                        }
                        if let error = weightInputError {
                            result = DoseResult(available: false, headline: "Invalid weight", math: "", formulation: "", warning: error)
                            return
                        }
                        if let error = concentrationInputError {
                            result = DoseResult(available: false, headline: "Invalid concentration", math: "", formulation: "", warning: error)
                            return
                        }
                        if let protocolDefinition {
                            result = ProtocolDoseCalculator.calculate(
                                definition: protocolDefinition,
                                kg: kg,
                                strength: selectedStrength,
                                concentration: activeConcentration,
                                builtInPreset: usingBuiltInPreset ? selectedBuiltInPreset : nil,
                                prescribedRate: MedicationSafety.parsePositive(prescribedPotassiumRate)
                            )
                        } else {
                            result = ClinicalData.calculate(
                                medication: medication,
                                kg: kg,
                                strength: selectedStrength,
                                concentration: activeConcentration
                            )
                        }
    }

    private var numericWeight: Double {
        MedicationSafety.parsePositive(patientWeight) ?? 0
    }

    private var weightInputError: String? {
        let entered = patientWeight.trimmingCharacters(in: .whitespacesAndNewlines)
        if entered.isEmpty && (protocolDefinition?.doseBasis.requiresWeight == false && !MedicationSafety.requiresEligibilityWeight(key: protocolDefinition?.medicationKey ?? "")) { return nil }
        guard MedicationSafety.parsePositive(entered) != nil, MedicationSafety.positiveFinite(kg) else {
            return "Enter a finite positive weight using a decimal point, not a comma or grouping separator."
        }
        return nil
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
        if let clinicOverride { return clinicOverride }
        return selectedBuiltInPreset.map { MedicationFormulations.definition($0.definition, for: medication) }
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
        MedicationSafety.parsePositive(concentration)
    }

    private var recommendedFrequency: String {
        protocolDefinition?.frequency ?? medication.frequency
    }

    private var administrationSelection: DoseRangeSelection? {
        guard let selection = doseSelection else { return nil }
        return MedicationSafety.perAdministration(selection, frequency: recommendedFrequency, dosesPerDay: dosesPerDay)
    }

    private var requiresRibbonApplication: Bool {
        medication.generic == "Mirtazapine transdermal" && medication.brand == "Mirataz"
    }

    private var usesGalliprantChart: Bool {
        protocolDefinition == nil && medication.generic == "Grapiprant" && medication.brand == "Galliprant" &&
            !medication.source.hasPrefix("USER") && !medication.source.hasPrefix("CUSTOM")
    }

    private var galliprantPlan: LabeledTabletPlan? {
        guard usesGalliprantChart else { return nil }
        return MedicationSafety.galliprantPlan(weight: numericWeight, unit: patientWeightUnit)
    }

    private var requiresPrescribedPotassiumRate: Bool {
        MedicationSafety.requiresPrescribedPotassiumRate(key: protocolDefinition?.medicationKey ?? "")
    }

    private var prescribedRateInputError: String? {
        guard requiresPrescribedPotassiumRate else { return nil }
        return MedicationSafety.validPotassiumRate(MedicationSafety.parsePositive(prescribedPotassiumRate)) ? nil :
            "Enter the veterinarian-prescribed rate in mEq/kg/hr, greater than zero and no more than 0.5."
    }

    private var concentrationInputError: String? {
        if medication.formulation?.bonqat == true && MedicationSafety.parsePositive(concentration) != 50 {
            return "Bonqat requires the labeled 50 mg/mL oral solution. Choose the separate entry for another product."
        }
        let needsValue = (protocolDefinition?.doseBasis.supportsConcentration == true &&
            protocolDefinition?.concentration != nil) ||
            ([MedicationForm.liquid, .injection].contains(medication.form) && medication.concentration != nil)
        let entered = concentration.trimmingCharacters(in: .whitespacesAndNewlines)
        if !entered.isEmpty && MedicationSafety.parsePositive(entered) == nil {
            return "Use a finite positive concentration with a decimal point, not a comma. No default will be substituted."
        }
        if needsValue && entered.isEmpty { return "Enter and verify the product concentration; no default will be substituted." }
        if let issue = MedicationSafety.insulinConcentrationIssue(
            presetID: selectedBuiltInPreset?.id, concentration: MedicationSafety.parsePositive(entered)) {
            return issue
        }
        if let issue = MedicationSafety.buprenorphineConcentrationIssue(
            presetID: selectedBuiltInPreset?.id, concentration: MedicationSafety.parsePositive(entered)) {
            return issue
        }
        if protocolDefinition?.doseBasis.isRate == true && !entered.isEmpty && !infusionConcentrationConfirmed {
            return "Confirm that this is the final prepared infusion concentration before calculating a pump rate."
        }
        return nil
    }

    private var administrationReviewReason: String? {
        if medication.formulation?.bonqat == true && selectedFrequency != .recommended {
            return "Bonqat uses a single pre-visit dose and may be given on two consecutive days. Repeating course schedules require a separately reviewed protocol."
        }
        if let error = prescribedRateInputError { return error }
        if let error = concentrationInputError { return error }
        if recommendedFrequency.lowercased().contains("total per week") {
            return "Weekly totals require a separately reviewed cycle schedule; a daily-frequency override is not valid."
        }
        let route = ((medication.formulation != nil && protocolDefinition?.medicationKey.hasPrefix("builtin|") == true ? selectedBuiltInPreset?.route : nil) ?? activeRoute).uppercased()
        if (route.contains("PO") || route.contains("ORAL")) && ["IV", "IM", "SC"].contains(where: route.contains) {
            return "Mixed oral/injectable entry: confirm one route and its matching product concentration in a route-specific protocol."
        }
        if let id = selectedBuiltInPreset?.id,
           let ceiling = ["furosemide-dog-2": 12.0, "furosemide-cat-2": 6.0, "enrofloxacin-cat-1": 5.0][id],
           let perDose = administrationSelection, let count = dosesPerDay, kg > 0 {
            // MSD/Merck cardiac table: chronic oral daily ceilings. Do not
            // lower the dose silently; keep reference math and block instructions.
            let delivered = max(perDose.selected, selectedSolidPlan?.deliveredMg ?? perDose.selected)
            if delivered * count / kg > ceiling + 1e-12 {
                return "Selected dose/frequency exceeds the cited daily ceiling for this protocol. Review the complete plan."
            }
        }
        if selectedBuiltInPreset?.highRisk == true {
            return "High-risk protocol: use the visible calculation with the veterinarian's monitored administration plan."
        }
        if medication.kind == .robenacoxibCatBand && dosesPerDay != 1 {
            return "ONSIOR is limited to one dose per day in this labeled entry."
        }
        if usesGalliprantChart && dosesPerDay != 1 { return "This GALLIPRANT chart is once daily only." }
        if usesGalliprantChart && galliprantPlan == nil { return "Weight is outside or between the printed product-chart bands; do not extrapolate." }
        if requiresRibbonApplication && dosesPerDay != 1 { return "This Mirataz entry is once daily only." }
        if dosesPerDay == nil && protocolDefinition?.doseBasis.isRate != true {
            return "Select one explicit veterinarian-approved schedule; alternative/PRN/titration text is not a fixed frequency."
        }
        if MedicationSafety.dailyTotal(recommendedFrequency) && administrationSelection == nil {
            return "A total daily dose requires an explicit within-day division schedule."
        }
        return nil
    }

    private var activeRoute: String {
        protocolDefinition?.route ?? medication.route
    }

    var body: some View {
        if medication.generic == "Gabapentin" && !medication.source.hasPrefix("USER-SOURCE-BACKED") && !medication.source.hasPrefix("CUSTOM-UNVERIFIED") {
            ClinicGabapentinView(species: species, weight: patientWeight, unit: patientWeightUnit, lockedForm: medication.form.rawValue)
        } else { referenceBody }
    }

    private var referenceBody: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
            Form {
                Section {
                    Text(medication.displayName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.blue)
                    Text(medication.indication)
                }

                if medication.generic == "Buprenorphine" {
                    Section("Additional concentration") {
                        Button("0.6 mg/mL · prescribed-dose conversion") { prescribedBuprenorphine = true }
                    }
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

                    if let error = weightInputError {
                        Text(error).font(.caption).foregroundStyle(AppTheme.orange)
                            .accessibilityIdentifier("dose.weight.error")
                    }
                    if numericWeight > 0 {
                        Text("\(ClinicalData.format(kg)) kg / \(ClinicalData.format(ClinicalData.kgToLb(kg))) lb")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else if (protocolDefinition?.doseBasis.requiresWeight == false && !MedicationSafety.requiresEligibilityWeight(key: protocolDefinition?.medicationKey ?? "")) {
                        Text("The selected protocol uses a fixed per-patient/eye dose; weight is optional for the arithmetic.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Enter a patient weight to enable automatic calculation.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.orange)
                    }
                }

                if let source = medication.formulation?.productSource, let url = URL(string: source) {
                    Section("Product strength source") {
                        if let sources = medication.formulation?.productSources, sources.count > 1 {
                            DisclosureGroup("Product label references") {
                                ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                                    if let labelURL = URL(string: source) { Link("Product label \(index + 1)", destination: labelURL) }
                                }
                            }
                        } else { Link("Official product label", destination: url) }
                        Text("Verify the exact product, release type and route. For prepared liquids and infusions, use the verified final concentration.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !activeStrengths.isEmpty {
                    Section("Product strength") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                            ForEach(Array(activeStrengths.enumerated()), id: \.offset) { index, value in
                                Button("\(MedicationSafety.input(value)) mg") { selectedStrengthIndex = index }
                                    .buttonStyle(.bordered)
                                    .tint(selectedStrengthIndex == index ? AppTheme.blue : .secondary)
                                    .accessibilityAddTraits(selectedStrengthIndex == index ? .isSelected : [])
                            }
                        }
                    }
                }

                let needsProtocolConcentration = protocolDefinition?.doseBasis.supportsConcentration == true && !(medication.formulation != nil && [.tablet, .capsule].contains(medication.form))
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
                    Section(protocolDefinition?.doseBasis.isRate == true ? "Final infusion concentration (\(concentrationUnit))" : "Concentration (\(concentrationUnit)) — verify product") {
                        if selectedBuiltInPreset?.id.hasPrefix("ampicillin-sulbactam-") == true {
                            Text("TOTAL COMBINED ampicillin + sulbactam mg/mL, after preparation; not ampicillin alone.")
                                .font(.footnote.bold())
                        }
                        if let values = medication.formulation?.concentrations {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                                ForEach(values, id: \.self) { value in
                                    Button("\(MedicationSafety.input(value)) mg/mL") { concentration = MedicationSafety.input(value) }
                                        .buttonStyle(.bordered)
                                        .tint(activeConcentration == value ? AppTheme.blue : .secondary)
                                }
                            }
                        }
                        if medication.generic == "Pregabalin" {
                            Text("For a compounded suspension, enter the exact bottle concentration. Product strength does not select a dose regimen.").font(.footnote)
                        }
                        TextField(concentrationUnit, text: $concentration)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("dose.concentration")
                        if let error = concentrationInputError {
                            Text(error).foregroundStyle(AppTheme.orange)
                                .accessibilityIdentifier("dose.concentration.error")
                        }
                        if protocolDefinition?.doseBasis.isRate == true {
                            Text("Enter the concentration of the final prepared infusion in \(concentrationUnit), including any dilution. Stock vial concentration is not the pump concentration after dilution.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Toggle("Final prepared infusion concentration verified", isOn: $infusionConcentrationConfirmed)
                                .accessibilityIdentifier("dose.infusion.concentration.verified")
                        } else {
                            Text("Enter the exact product concentration in \(concentrationUnit).")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if requiresPrescribedPotassiumRate {
                    Section("Prescribed potassium rate (mEq/kg/hr)") {
                        TextField("Veterinarian-prescribed mEq/kg/hr", text: $prescribedPotassiumRate)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("dose.potassium.prescribed.rate")
                        Text("Use the current serum potassium and the complete fluid prescription. Maximum 0.5 mEq/kg/hr. Never bolus KCl-containing fluids. Account for all potassium sources.")
                            .font(.footnote)
                        if let error = prescribedRateInputError { Text(error).foregroundStyle(AppTheme.orange) }
                    }
                }

                if let selection = doseSelection, selection.hasRange {
                    Section("Dose level") {
                                Picker("Dose level", selection: $selectedDoseLevel) {
                                    ForEach([DoseSelectionLevel.low, DoseSelectionLevel.high]) { level in
                                        Text(level.rawValue).tag(level)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .accessibilityIdentifier("dose.level")
                    }
                }
                if selectedSolidPlan != nil {
                    Section("Tablet / capsule rounding") {
                                Picker("Whole-unit rounding", selection: $solidRounding) {
                                    ForEach(SolidDoseRounding.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .accessibilityIdentifier("dose.rounding")
                    }
                }
                    if (medication.kind != .protocolOnly || protocolDefinition != nil), protocolDefinition?.doseBasis.isRate != true {
                        Section("Optional veterinarian frequency") {
                            Text("Use the source-backed recommended frequency unless the prescribing veterinarian directs a different schedule. Choosing an override does not validate the new schedule. For total-daily-dose entries, the selected daily amount is divided by administrations/day before formulation rounding.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                frequencyButton(.recommended, title: "Recommended")
                                frequencyButton(.q6h, title: "Every 6 h")
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

                            if selectedFrequency != .recommended, MedicationSafety.dailyTotal(recommendedFrequency) {
                                Text("This entry is calculated as a total daily dose. The unrounded daily target is kept unchanged and divided by the selected number of administrations per day. Confirm the delivered amount after any formulation rounding.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if canPlanSupply {
                        Section("Quantity / treatment duration") {
                            if medication.kind == .robenacoxibCatBand {
                                Toggle("Prior oral/injectable doses in this course reviewed", isOn: $priorCourseHistoryConfirmed)
                                Stepper("Previous treatment-day doses: \(priorCourseDoses)", value: $priorCourseDoses, in: 0...3)
                                Text("Maximum 3 total doses on 3 consecutive days, no more than one dose/day, including injections already given. Confirm age ≥4 months and the next dose time.").font(.caption)
                                HStack {
                                    supplyButton(days: 1, title: "1 day")
                                    supplyButton(days: 2, title: "2 days")
                                    supplyButton(days: 3, title: "3 days")
                                }
                            } else {
                            HStack {
                                supplyButton(days: 7, title: "7 days")
                                supplyButton(days: 14, title: "2 weeks")
                                supplyButton(days: 30, title: "30 days")
                            }
                            }

                        }
                    }
                Section {
                    Button {
                        calculateCandidate()
                        weightFieldFocused = false
                        DispatchQueue.main.async { withAnimation { scrollProxy.scrollTo("dose.candidate.anchor", anchor: .top) } }
                    } label: {
                        Label("Calculate dose", systemImage: "function")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                                        .disabled(prescribedRateInputError != nil || weightInputError != nil || !numericWeight.isFinite || numericWeight < 0 || ((protocolDefinition?.doseBasis.requiresWeight ?? true) && numericWeight <= 0) || concentrationInputError != nil || (medication.kind == .protocolOnly && protocolDefinition == nil))
                    .accessibilityIdentifier("dose.calculate")
                }

                if let result {
                    Section("Calculated candidate") {
                        if result.available, let selected = administrationSelection ?? doseSelection {
                            Text("\(ClinicalData.format(selected.selected)) \(selected.unit) • \(activeFrequencyLabel)")
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.blue)
                                .accessibilityIdentifier("dose.candidate.amount")
                        } else {
                            Text(result.headline).font(.headline).foregroundStyle(AppTheme.orange)
                        }
                        if result.available, let summary = readableAdministrationSummary {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Selected dose — quantity and schedule")
                                    .font(.caption.bold())
                                Text(summary.components(separatedBy: "\n").first ?? summary)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.blue)
                                    .accessibilityIdentifier("dose.result.quantity")
                                if let note = readableAdministrationNote {
                                    Text(note)
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.orange)
                                        .accessibilityIdentifier("dose.result.quantity.note")
                                }
                            }
                        }
                        if result.available, let solid = selectedSolidPlan {
                            Text(administrationInstruction(for: solid))
                                .font(.subheadline.weight(.semibold))
                                .accessibilityIdentifier("dose.candidate.rounded")
                        }
                        if let days = supplyDays, result.available {
                            Text(supplySummary(days: days))
                                .font(.subheadline.weight(.semibold))
                                .accessibilityIdentifier("dose.supply.summary")
                        }
                        if !activeRoute.isEmpty { LabeledContent("Route", value: activeRoute) }
                        Text("Calculation for veterinarian review; verify product, patient and plan before use.")
                            .font(.caption)
                    }
                    .id("dose.candidate.anchor")

                    Section("Equation, math & reference") {
                        Text(result.headline)
                            .font(.title3.bold())
                            .foregroundStyle(result.available ? AppTheme.blue : AppTheme.orange)

                        if !result.math.isEmpty {
                            LabeledContent("Math", value: result.math)
                                .accessibilityIdentifier("dose.result.math")
                        }
                        if let summary = readableAdministrationSummary, summary.contains("\n") {
                            Text(summary.components(separatedBy: "\n").dropFirst().joined(separator: "\n"))
                                .font(.footnote)
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

                            if let perDose = administrationSelection, MedicationSafety.dailyTotal(recommendedFrequency) {
                                LabeledContent("Target per administration", value: "\(ClinicalData.format(perDose.selected)) \(perDose.unit)")
                                Text("\(perDose.math). Rounding, if chosen, is applied after this division.").font(.caption)
                            }
                            if let reason = administrationReviewReason {
                                Text("Administration plan blocked: " + reason).foregroundStyle(AppTheme.orange)
                            }
                            if usesGalliprantChart, let chart = galliprantPlan {
                                Text("Product chart: \(ClinicalData.format(chart.units)) × \(ClinicalData.format(chart.strengthMg)) mg tablet, once daily (\(chart.band)).")
                                    .accessibilityIdentifier("dose.galliprant.chart")
                                Text("Chart reference, not generic whole-tablet rounding. Only 20 mg and 60 mg GALLIPRANT tablets are scored; never halve the 100 mg tablet. Verify labeled age and patient eligibility.").font(.caption)
                            } else if usesGalliprantChart {
                                Text("No chart dose generated; consult the product chart and veterinarian.")
                            } else if let solid = selectedSolidPlan {
                                LabeledContent("Raw formulation", value: "\(ClinicalData.format(solid.rawUnits)) \(solidUnitName)")



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
                                    LabeledContent("Entered concentration — verify", value: "\(ClinicalData.format(c)) \(protocolDefinition?.doseBasis.concentrationLabel ?? "mg/mL")")
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



                    if result.available, medication.form == .injection {
                        Section("Injectable administration") {
                            Text("Immediate-use injectable: this calculator shows the single administration dose/volume only. No 7-day, 2-week, or 30-day take-home supply counter is available for injectable medications.")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.blue)
                                .accessibilityIdentifier("dose.injectable.single")
                        }
                    }


                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Recommended Dose") {
                        if let selection = doseSelection, !selection.hasRange {
                            calculateCandidate()
                            weightFieldFocused = false
                            DispatchQueue.main.async { withAnimation { scrollProxy.scrollTo("dose.candidate.anchor", anchor: .top) } }
                        } else { recommendationHelp = true }
                    }.accessibilityIdentifier("dose.recommended")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("dose.done")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        weightFieldFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .accessibilityIdentifier("dose.keyboard.done")
                }
            }
            .onAppear {
                if let c = protocolDefinition?.concentration ?? medication.concentration {
                    concentration = MedicationSafety.input(c)
                }
            }
            .onChange(of: patientWeight) { _, _ in
                result = nil
            }
            .onChange(of: patientWeightUnit) { _, _ in
                result = nil
            }
            .onChange(of: selectedStrengthIndex) { _, _ in
                result = nil
            }
            .onChange(of: concentration) { _, _ in
                infusionConcentrationConfirmed = false
                result = nil
            }
            .onChange(of: prescribedPotassiumRate) { _, _ in
                result = nil
            }
            .onChange(of: infusionConcentrationConfirmed) { _, _ in
                result = nil
            }
            .sheet(isPresented: $prescribedBuprenorphine) { PrescribedBuprenorphineView(species: species) }
            .alert("Recommended Dose", isPresented: $recommendationHelp) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This selection has no single source-supported default. Choose the appropriate species, indication, route and product protocol. For a dose range, the treating veterinarian selects the dose; its midpoint is not automatically recommended.")
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
                result = nil
            }
            .onChange(of: solidRounding) { _, _ in
                result = nil
            }
            .onChange(of: selectedFrequency) { _, _ in result = nil }
            .onChange(of: priorCourseDoses) { _, _ in result = nil }
            .onChange(of: priorCourseHistoryConfirmed) { _, _ in result = nil }
            .onChange(of: selectedPresetIndex) { _, _ in
                prescribedPotassiumRate = ""
                infusionConcentrationConfirmed = false
                result = nil
                supplyDays = nil
                selectedFrequency = .recommended
                selectedStrengthIndex = 0
                if let c = protocolDefinition?.concentration {
                    concentration = MedicationSafety.input(c)
                } else if medication.kind == .protocolOnly {
                    concentration = ""
                }
            }
            .onChange(of: protocolStore.definitions) { _, _ in
                supplyDays = nil
                selectedFrequency = .recommended
                prescribedPotassiumRate = ""
                infusionConcentrationConfirmed = false
                result = nil
                selectedStrengthIndex = 0
                if let c = protocolDefinition?.concentration {
                    concentration = MedicationSafety.input(c)
                } else if medication.kind == .protocolOnly {
                    concentration = ""
                }
            }
            }
        }
    }

    private var canPlanSupply: Bool {
        guard dosesPerDay != nil, administrationReviewReason == nil,
              administrationSelection != nil, concentrationInputError == nil,
              (medication.kind != .protocolOnly || protocolDefinition != nil),
              selectedBuiltInPreset?.highRisk != true,
              medication.form != .injection, protocolDefinition?.doseBasis.isRate != true else { return false }
        if usesGalliprantChart { return galliprantPlan != nil }
        if let solid = selectedSolidPlan, let selection = administrationSelection {
            return MedicationSafety.withinRange(solid.deliveredMg, selection)
        }
        return true
    }

    private var activeFrequencyLabel: String {
        selectedFrequency == .recommended ? recommendedFrequency : selectedFrequency.rawValue
    }

    private var dosesPerDay: Double? {
        if let override = selectedFrequency.dosesPerDay { return override }
        return MedicationSafety.regularDosesPerDay(recommendedFrequency)
    }

    private var doseMultiplierPerDay: Double? {
        guard let dosesPerDay else { return nil }
        if MedicationSafety.dailyTotal(recommendedFrequency) {
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
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(identifier)
        } else {
            Button(title) {
                selectedFrequency = choice
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
            return AdministrationMath.selection(for: protocolDefinition, kg: kg, level: selectedDoseLevel, prescribedRate: MedicationSafety.parsePositive(prescribedPotassiumRate))
        }
        return AdministrationMath.selection(for: medication, kg: kg, level: selectedDoseLevel)
    }

    private func selection(for level: DoseSelectionLevel) -> DoseRangeSelection? {
        if let protocolDefinition {
            return AdministrationMath.selection(for: protocolDefinition, kg: kg, level: level, prescribedRate: MedicationSafety.parsePositive(prescribedPotassiumRate))
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

    // An additive rendering of the existing selected-dose math, never a new
    // dosing rule or permission to split a tablet/capsule.
    private var readableAdministrationSummary: String? {
        guard weightInputError == nil, concentrationInputError == nil,
              let dose = administrationSelection else { return nil }
        if usesGalliprantChart, let chart = galliprantPlan {
            return "\(ClinicalData.format(chart.units)) tablet(s) of \(ClinicalData.format(chart.strengthMg)) mg • \(activeFrequencyLabel)\nProduct-chart amount: \(ClinicalData.format(chart.deliveredMg)) mg per administration"
        }
        if usesGalliprantChart { return nil }
        if let solid = selectedSolidPlan, let strength = selectedStrength {
            return "\(ClinicalData.format(solid.rawUnits)) \(solidUnitName) equivalent per administration • \(activeFrequencyLabel)\n\(ClinicalData.format(dose.selected)) mg ÷ \(ClinicalData.format(strength)) mg per unit = \(ClinicalData.format(solid.rawUnits)) \(solidUnitName)"
        }
        if let volume = selectedAdministrationVolume, volume.unit == "mL" || volume.unit == "mL/hr" {
            let schedule = volume.unit == "mL/hr" ? "continuous infusion" : "per administration • \(activeFrequencyLabel)"
            let concentrationText = activeConcentration.map {
                " • at \(ClinicalData.format($0)) \(protocolDefinition?.doseBasis.concentrationLabel ?? "mg/mL")"
            } ?? ""
            return "\(ClinicalData.format(volume.value)) \(volume.unit) \(schedule)\nSelected amount: \(ClinicalData.format(dose.selected)) \(dose.unit)\(concentrationText)"
        }
        return nil
    }

    private var readableAdministrationNote: String? {
        guard readableAdministrationSummary != nil else { return nil }
        if let reason = administrationReviewReason {
            return "Calculation only — administration plan requires review. " + reason
        }
        if let solid = selectedSolidPlan {
            let whole = MedicationSafety.snapIntegerBoundary(solid.rawUnits)
            if whole != whole.rounded() {
                return medication.form == .capsule
                    ? "Fractional capsule equivalent only. Do not split or open capsules from this calculation; verify a suitable strength or formulation with the prescribing veterinarian."
                    : "Fractional tablet equivalent only. Verify that this specific tablet can be divided accurately; existing whole-tablet rounding options remain below."
            }
        }
        return "Confirm the selected product, route and schedule before administration."
    }

    private var selectedSolidPlan: SolidAdministrationPlan? {
        guard !usesGalliprantChart, let selection = administrationSelection,
              selection.unit == "mg", !selection.isRate,
              let strength = selectedStrength, MedicationSafety.positiveFinite(strength),
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
        guard !requiresRibbonApplication, let selection = administrationSelection,
              concentrationInputError == nil, routeSupportsMeasuredVolume else { return nil }
        return AdministrationMath.volume(selection: selection,
            basis: protocolDefinition?.doseBasis, concentration: activeConcentration)
    }

    private func administrationInstruction(for solid: SolidAdministrationPlan) -> String {
        if let reason = administrationReviewReason { return "Plan blocked: " + reason }
        guard let selection = administrationSelection,
              MedicationSafety.withinRange(solid.deliveredMg, selection) else {
            return "Rounded amount is outside the selected dose range. Verify a different strength, permitted tablet fraction or explicitly reviewed protocol."
        }
        let qty = ClinicalData.format(solid.roundedUnits)
        return "Calculated candidate: \(qty) \(solidUnitName) per administration, \(activeFrequencyLabel). Veterinarian confirmation required."
    }

    private func volumeInstruction(_ volume: (value: Double, unit: String)) -> String {
        if let reason = administrationReviewReason { return "Plan blocked: " + reason }
        let amount = ClinicalData.format(volume.value)
        if volume.unit == "mL/hr" {
            return "Calculated rate: \(amount) mL/hr. Confirm the infusion concentration, pump resolution and monitoring."
        }
        return "Calculated candidate: \(amount) \(volume.unit) per administration, \(activeFrequencyLabel). Veterinarian confirmation required."
    }

    private func varianceText(_ percent: Double) -> String {
        if abs(percent) < 0.005 { return "0% (matches target)" }
        let sign = percent > 0 ? "+" : ""
        return "\(sign)\(ClinicalData.format(percent))%"
    }

    private func supplySummary(days: Int) -> String {
        guard days > 0, canPlanSupply, let dosesPerDay else {
            return "Dispense calculation blocked: verify inputs, dosage form, selected rounding and an unambiguous schedule."
        }
        if let ceiling = MedicationSafety.documentedDaysCeiling(recommendedFrequency), days > ceiling {
            return "Blocked: the selected entry documents a \(ceiling)-day course. Review the prescribed duration instead of extending this schedule automatically."
        }
        if medication.kind == .robenacoxibCatBand {
            guard priorCourseHistoryConfirmed, (0...3).contains(priorCourseDoses),
                  days <= 3 - priorCourseDoses else {
                return "Blocked: ONSIOR allows no more than 3 once-daily doses across oral and injectable formulations in the current 3-day course. Confirm previous doses and remaining consecutive treatment days."
            }
        }
        if requiresRibbonApplication && days > 14 {
            return "Blocked: this Mirataz entry describes a 14-day labeled course; verify a separate plan."
        }
        if medication.brand == "Apoquel initial" && days > 14 {
            return "Blocked: the initial twice-daily Apoquel phase must not exceed 14 days. Select the appropriate maintenance entry."
        }
        let administrations = AdministrationMath.administrations(days: days, dosesPerDay: dosesPerDay)
        guard administrations > 0 else { return "Dispense calculation outside numeric limits." }
        let schedule = activeFrequencyLabel
        if protocolDefinition?.doseBasis == .ribbonInch, let selection = administrationSelection {
            return "\(days) days • \(schedule) • \(administrations) applications of \(ClinicalData.format(selection.selected))-inch ointment strip to each affected eye. Verify the prescribed eye(s); do not convert strip length to drops, mL or tube quantity."
        }
        if usesGalliprantChart, let plan = galliprantPlan {
            let total = ceil(MedicationSafety.snapIntegerBoundary(plan.units * Double(administrations)))
            return "\(days) days • \(schedule) • \(ClinicalData.format(plan.units)) × \(ClinicalData.format(plan.strengthMg)) mg tablets per administration • quantity to dispense: \(ClinicalData.format(total)) whole tablets. Chart reference; veterinarian confirmation required."
        }
        if requiresRibbonApplication {
            return "\(days) days • \(schedule) • \(administrations) applications using the labeled ribbon length. Do not convert ointment to a liquid volume."
        }
        if let solid = selectedSolidPlan, let selection = administrationSelection,
           MedicationSafety.withinRange(solid.deliveredMg, selection) {
            let total = ceil(MedicationSafety.snapIntegerBoundary(solid.roundedUnits * Double(administrations)))
            guard total.isFinite else { return "Dispense calculation outside numeric limits." }
            return "\(days) days • \(schedule) • \(administrations) administration(s) • \(ClinicalData.format(solid.roundedUnits)) \(solidUnitName) per administration • quantity to dispense: \(ClinicalData.format(total)) \(solidUnitName)"
        }
        if let volume = selectedAdministrationVolume, volume.unit == "mL" {
            let total = volume.value * Double(administrations)
            guard MedicationSafety.positiveFinite(total) else { return "Dispense calculation outside numeric limits." }
            return "\(days) days • \(schedule) • \(administrations) administration(s) • \(ClinicalData.format(volume.value)) mL per administration • calculated quantity to dispense: \(ClinicalData.format(total)) mL"
        }
        return "No verified administration unit is available. Keep the dose math as a reference; obtain a product-specific dispensing plan."
    }

    private func formatRange(_ low: Double, _ high: Double) -> String {
        abs(low - high) < 0.0000001
            ? ClinicalData.format(low)
            : "\(ClinicalData.format(low))–\(ClinicalData.format(high))"
    }
}

