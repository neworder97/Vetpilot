import SwiftUI
import Foundation

enum ProtocolDoseBasis: String, CaseIterable, Identifiable, Codable {
    case mgKg = "mg/kg"
    case mgLb = "mg/lb"
    case fixedMg = "Fixed mg/patient"
    case unitsKg = "units/kg"
    case fixedUnits = "Fixed units/patient"
    case mcgKg = "mcg/kg"
    case mcgKgMin = "mcg/kg/min"
    case mgKgHr = "mg/kg/hr"
    case mEqKg = "mEq/kg"
    case mEqKgHr = "mEq/kg/hr"
    case mLKg = "mL/kg"
    case dropsEye = "drops/eye"
    case gKg = "g/kg"
    case mgM2 = "mg/m²"

    var id: String { rawValue }

    var amountUnit: String {
        switch self {
        case .mgKg, .mgLb, .fixedMg, .mgKgHr, .mgM2: return "mg"
        case .unitsKg, .fixedUnits: return "units"
        case .mcgKg, .mcgKgMin: return "mcg"
        case .mEqKg, .mEqKgHr: return "mEq"
        case .mLKg: return "mL"
        case .dropsEye: return "drop(s)/eye"
        case .gKg: return "g"
        }
    }

    var isRate: Bool {
        switch self {
        case .mcgKgMin, .mgKgHr, .mEqKgHr: return true
        default: return false
        }
    }

    var supportsStrength: Bool {
        switch self {
        case .mgKg, .mgLb, .fixedMg, .mgM2: return true
        default: return false
        }
    }

    var supportsConcentration: Bool {
        switch self {
        case .mgKg, .mgLb, .fixedMg, .unitsKg, .fixedUnits, .mcgKg, .mcgKgMin, .mgKgHr, .mEqKg, .mEqKgHr, .gKg, .mgM2:
            return true
        case .mLKg, .dropsEye:
            return false
        }
    }

    var concentrationLabel: String {
        switch self {
        // Mass-based liquid/injectable products are entered in mg/mL. VetPilot converts
        // mcg or g dose equations to mg before converting to volume. This keeps the
        // concentration field aligned with the way most injectable/liquid labels are read.
        case .mgKg, .mgLb, .fixedMg, .mgKgHr, .mgM2, .mcgKg, .mcgKgMin, .gKg: return "mg/mL"
        case .unitsKg, .fixedUnits: return "units/mL"
        case .mEqKg, .mEqKgHr: return "mEq/mL"
        case .mLKg: return "mL"
        case .dropsEye: return "drops"
        }
    }

    var requiresWeight: Bool {
        switch self {
        case .fixedMg, .fixedUnits, .dropsEye: return false
        default: return true
        }
    }
}

struct ProtocolMedicationDefinition: Identifiable, Codable, Equatable {
    var id: String { medicationKey }
    var medicationKey: String
    var generic: String
    var speciesRaw: String
    var doseBasisRaw: String
    var minDose: Double
    var maxDose: Double
    var frequency: String
    var route: String
    var strengths: [Double]
    var concentration: Double?
    var sourceReference: String
    var notes: String
    var veterinarianApproved: Bool

    var species: Species { Species(rawValue: speciesRaw) ?? .dog }
    var doseBasis: ProtocolDoseBasis { ProtocolDoseBasis(rawValue: doseBasisRaw) ?? .mgKg }

    var validationIssue: String? {
        guard Species(rawValue: speciesRaw) != nil else { return "Unknown species; do not assume dog." }
        guard ProtocolDoseBasis(rawValue: doseBasisRaw) != nil else { return "Unknown dose basis; do not assume mg/kg." }
        guard MedicationSafety.validRange(low: minDose, high: maxDose) else { return "Invalid or reversed dose range." }
        guard strengths.allSatisfy(MedicationSafety.positiveFinite), MedicationSafety.optionalPositive(concentration) else {
            return "Invalid strength or concentration."
        }
        return nil
    }

    static func key(for medication: Medication, species: Species) -> String {
        [medication.generic, medication.brand, medication.form.rawValue, species.rawValue]
            .joined(separator: "|")
            .lowercased()
    }
}

struct BuiltInProtocolPreset: Identifiable, Equatable {
    let id: String
    let generic: String
    let species: Species
    let label: String
    let doseBasis: ProtocolDoseBasis
    let minDose: Double
    let maxDose: Double
    let frequency: String
    let route: String
    let strengths: [Double]
    let concentration: Double?
    let sourceReference: String
    let notes: String
    let confidence: String
    let highRisk: Bool

    var displayLabel: String {
        let value = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return doseBasis.rawValue }
        if value.count <= 82 { return value }
        return String(value.prefix(79)) + "…"
    }

    var definition: ProtocolMedicationDefinition {
        ProtocolMedicationDefinition(
            medicationKey: "builtin|\(id)",
            generic: generic,
            speciesRaw: species.rawValue,
            doseBasisRaw: doseBasis.rawValue,
            minDose: minDose,
            maxDose: maxDose,
            frequency: frequency,
            route: route,
            strengths: strengths,
            concentration: concentration,
            sourceReference: sourceReference,
            notes: notes,
            veterinarianApproved: true
        )
    }
}

@MainActor
final class ProtocolMedicationStore: ObservableObject {
    @Published private(set) var definitions: [ProtocolMedicationDefinition] = []

    private let key = "ferguson.vetpilot.protocol-medications.v1"

    init() { load() }

    func definition(for medication: Medication, species: Species) -> ProtocolMedicationDefinition? {
        let key = ProtocolMedicationDefinition.key(for: medication, species: species)
        return definitions.first { $0.medicationKey == key }
    }

    func save(_ definition: ProtocolMedicationDefinition) {
        if let index = definitions.firstIndex(where: { $0.medicationKey == definition.medicationKey }) {
            definitions[index] = definition
        } else {
            definitions.append(definition)
        }
        persist()
    }

    func remove(for medication: Medication, species: Species) {
        let key = ProtocolMedicationDefinition.key(for: medication, species: species)
        definitions.removeAll { $0.medicationKey == key }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ProtocolMedicationDefinition].self, from: data) else {
            definitions = []
            return
        }
        definitions = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(definitions) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

enum ProtocolDoseCalculator {
    static func calculate(
        definition d: ProtocolMedicationDefinition,
        kg: Double,
        strength: Double?,
        concentration: Double?,
        builtInPreset: BuiltInProtocolPreset? = nil
    ) -> DoseResult {
        guard d.veterinarianApproved else {
            return DoseResult(
                available: false,
                headline: "Protocol approval required",
                math: "",
                formulation: "",
                warning: "Enable this calculator only after the dose rule has been reviewed and approved by the prescribing veterinarian/clinic."
            )
        }

        if let issue = d.validationIssue {
            return DoseResult(available: false, headline: "Invalid protocol definition", math: "", formulation: "", warning: issue)
        }
        guard MedicationSafety.optionalPositive(strength), MedicationSafety.optionalPositive(concentration) else {
            return DoseResult(available: false, headline: "Invalid strength or concentration", math: "", formulation: "",
                warning: "Invalid entered values cannot fall back silently to a reference concentration.")
        }

        // A volume-per-weight rule already incorporates its reference strength.
        // Applying it unchanged to another product would change the drug amount.
        if d.doseBasis == .mLKg, let required = d.concentration,
           let entered = concentration, entered != required {
            return DoseResult(available: false, headline: "Volume protocol product mismatch",
                math: "", formulation: "",
                warning: "This mL/kg protocol requires \(MedicationSafety.display(required)) mg/mL. Select a reviewed protocol for a different product concentration.")
        }

        if let issue = MedicationSafety.insulinConcentrationIssue(
            presetID: builtInPreset?.id ?? MedicationSafety.builtinID(d.medicationKey), concentration: concentration ?? d.concentration) {
            return DoseResult(available: false, headline: "Insulin product mismatch",
                math: "", formulation: "", warning: issue)
        }

        if let issue = MedicationSafety.buprenorphineConcentrationIssue(
            presetID: builtInPreset?.id ?? MedicationSafety.builtinID(d.medicationKey),
            concentration: concentration ?? d.concentration) {
            return DoseResult(available: false, headline: "Buprenorphine product mismatch",
                math: "", formulation: "", warning: issue)
        }

        guard kg.isFinite, kg >= 0, (!d.doseBasis.requiresWeight || kg > 0) else {
            return DoseResult(
                available: false,
                headline: "Enter a valid weight",
                math: "",
                formulation: "",
                warning: "Weight must be greater than 0 kg for this protocol equation."
            )
        }

        if let issue = MedicationSafety.protocolEligibilityIssue(key: d.medicationKey, kg: kg) {
            return DoseResult(available: false, headline: "Protocol eligibility not met", math: "", formulation: "", warning: issue)
        }
        let maxDose = d.maxDose > 0 ? d.maxDose : d.minDose
        let low: Double
        var high: Double
        let basisText: String
        let unit = d.doseBasis.amountUnit

        switch d.doseBasis {
        case .mgKg, .unitsKg, .mcgKg, .mEqKg, .mLKg, .gKg:
            low = d.minDose * kg
            high = maxDose * kg
            basisText = "\(ClinicalData.format(kg)) kg × \(ClinicalData.format(d.minDose))" +
                (abs(d.minDose - maxDose) < 0.0000001 ? "" : "–\(ClinicalData.format(maxDose))") +
                " \(d.doseBasis.rawValue)"

        case .mgM2:
            let constant = d.species == .dog ? 0.101 : 0.100
            let bsa = constant * pow(kg, 2.0 / 3.0)
            low = d.minDose * bsa
            high = maxDose * bsa
            basisText = "BSA \(ClinicalData.format(bsa)) m² × \(ClinicalData.format(d.minDose))" +
                (abs(d.minDose - maxDose) < 0.0000001 ? "" : "–\(ClinicalData.format(maxDose))") + " mg/m²"

        case .mgLb:
            let lb = ClinicalData.kgToLb(kg)
            low = d.minDose * lb
            high = maxDose * lb
            basisText = "\(ClinicalData.format(lb)) lb × \(ClinicalData.format(d.minDose))" +
                (abs(d.minDose - maxDose) < 0.0000001 ? "" : "–\(ClinicalData.format(maxDose))") + " mg/lb"

        case .fixedMg, .fixedUnits, .dropsEye:
            low = d.minDose
            high = maxDose
            basisText = builtInPreset == nil ? "Clinic-entered fixed dose" : "Selected preloaded fixed-dose protocol"

        case .mcgKgMin:
            low = d.minDose * kg
            high = maxDose * kg
            basisText = "\(ClinicalData.format(kg)) kg × \(ClinicalData.format(d.minDose))" +
                (abs(d.minDose - maxDose) < 0.0000001 ? "" : "–\(ClinicalData.format(maxDose))") + " mcg/kg/min"

        case .mgKgHr, .mEqKgHr:
            low = d.minDose * kg
            high = maxDose * kg
            basisText = "\(ClinicalData.format(kg)) kg × \(ClinicalData.format(d.minDose))" +
                (abs(d.minDose - maxDose) < 0.0000001 ? "" : "–\(ClinicalData.format(maxDose))") + " \(d.doseBasis.rawValue)"
        }

        if let ceiling = MedicationSafety.maximumProtocolAmount(key: d.medicationKey) {
            guard low <= ceiling else {
                return DoseResult(available: false, headline: "Protocol ceiling exceeded", math: "", formulation: "",
                    warning: "Even the lower end exceeds the per-patient ceiling. A separately reviewed plan is required.")
            }
            high = min(high, ceiling)
        }
        guard MedicationSafety.positiveFinite(low), MedicationSafety.positiveFinite(high), high >= low else {
            return DoseResult(available: false, headline: "Calculation outside numeric limits", math: "", formulation: "", warning: "No dose has been produced.")
        }

        let amountText = abs(low - high) < 0.0000001
            ? "\(ClinicalData.format(low)) \(unit)"
            : "\(ClinicalData.format(low))–\(ClinicalData.format(high)) \(unit)"

        var headline = amountText
        var formulation = ""

        if d.doseBasis.isRate {
            switch d.doseBasis {
            case .mcgKgMin:
                headline = "\(amountText)/min"
            case .mgKgHr, .mEqKgHr:
                headline = "\(amountText)/hr"
            default:
                break
            }
        }

        if d.doseBasis.supportsStrength, let strength, strength > 0 {
            let a = low / strength
            let b = high / strength
            guard MedicationSafety.positiveFinite(a), MedicationSafety.positiveFinite(b) else {
                return DoseResult(available: false, headline: "Formulation outside numeric limits", math: "", formulation: "", warning: "No administration amount is available.")
            }
            formulation = abs(a - b) < 0.0000001
                ? "\(ClinicalData.format(a)) unit(s) of \(ClinicalData.format(strength)) mg; raw mathematical conversion—round only per selected protocol/label"
                : "\(ClinicalData.format(a))–\(ClinicalData.format(b)) unit(s) of \(ClinicalData.format(strength)) mg; raw mathematical conversion—round only per selected protocol/label"
        }

        if d.doseBasis.supportsConcentration, let c = concentration ?? d.concentration, c > 0 {
            let a: Double
            let b: Double
            switch d.doseBasis {
            case .mcgKgMin:
                // Dose is mcg/min; concentration is deliberately entered as mg/mL.
                a = (low / 1000.0) * 60.0 / c
                b = (high / 1000.0) * 60.0 / c
                formulation = abs(a - b) < 0.0000001
                    ? "\(ClinicalData.format(a)) mL/hr at \(ClinicalData.format(c)) \(d.doseBasis.concentrationLabel)"
                    : "\(ClinicalData.format(a))–\(ClinicalData.format(b)) mL/hr at \(ClinicalData.format(c)) \(d.doseBasis.concentrationLabel)"
            case .mgKgHr, .mEqKgHr:
                a = low / c
                b = high / c
                formulation = abs(a - b) < 0.0000001
                    ? "\(ClinicalData.format(a)) mL/hr at \(ClinicalData.format(c)) \(d.doseBasis.concentrationLabel)"
                    : "\(ClinicalData.format(a))–\(ClinicalData.format(b)) mL/hr at \(ClinicalData.format(c)) \(d.doseBasis.concentrationLabel)"
            case .mcgKg:
                // Dose is mcg; concentration is mg/mL.
                a = (low / 1000.0) / c
                b = (high / 1000.0) / c
                formulation = abs(a - b) < 0.0000001
                    ? "\(ClinicalData.format(a)) mL at \(ClinicalData.format(c)) \(d.doseBasis.concentrationLabel)"
                    : "\(ClinicalData.format(a))–\(ClinicalData.format(b)) mL at \(ClinicalData.format(c)) \(d.doseBasis.concentrationLabel)"
            case .gKg:
                // Dose is g; concentration is mg/mL.
                a = (low * 1000.0) / c
                b = (high * 1000.0) / c
                formulation = abs(a - b) < 0.0000001
                    ? "\(ClinicalData.format(a)) mL at \(ClinicalData.format(c)) \(d.doseBasis.concentrationLabel)"
                    : "\(ClinicalData.format(a))–\(ClinicalData.format(b)) mL at \(ClinicalData.format(c)) \(d.doseBasis.concentrationLabel)"
            default:
                a = low / c
                b = high / c
                formulation = abs(a - b) < 0.0000001
                    ? "\(ClinicalData.format(a)) mL at \(ClinicalData.format(c)) \(d.doseBasis.concentrationLabel)"
                    : "\(ClinicalData.format(a))–\(ClinicalData.format(b)) mL at \(ClinicalData.format(c)) \(d.doseBasis.concentrationLabel)"
            }
            guard MedicationSafety.positiveFinite(a), MedicationSafety.positiveFinite(b) else {
                return DoseResult(available: false, headline: "Formulation outside numeric limits", math: "", formulation: "", warning: "No administration volume is available.")
            }
        }

        let freq = d.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
        if !freq.isEmpty { headline += " \(freq)" }

        let source = d.sourceReference.trimmingCharacters(in: .whitespacesAndNewlines)
        let extra = d.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        var warning: String

        if let preset = builtInPreset {
            warning = "Preloaded veterinary reference protocol. VetPilot performs arithmetic after you choose the intended protocol; it does not select the diagnosis, indication, route, product, titration step, or treatment plan. Verify the final dose with the veterinarian."
            if preset.highRisk {
                warning += " High-risk/monitored protocol: confirm the selected branch, patient-specific contraindications, monitoring, and clinic/legal requirements before use."
            }
            if !preset.confidence.isEmpty {
                warning += " Research confidence: \(preset.confidence)."
            }
        } else {
            warning = "Clinic-entered \(d.speciesRaw) protocol. VetPilot performs arithmetic only; verify indication, route, patient factors, maximums, monitoring, and final dose before use."
        }

        if !source.isEmpty { warning += " Reference: \(source)." }
        if !extra.isEmpty { warning += " \(extra)" }

        return DoseResult(
            available: true,
            headline: headline,
            math: "\(basisText)\(MedicationSafety.maximumProtocolAmount(key: d.medicationKey) != nil ? "; applying per-patient ceiling" : "") = \(amountText)",
            formulation: formulation,
            warning: warning
        )
    }
}

struct ProtocolMedicationEditorView: View {
    let medication: Medication
    let species: Species
    @ObservedObject var store: ProtocolMedicationStore
    private let seed: ProtocolMedicationDefinition?
    @Environment(\.dismiss) private var dismiss

    @State private var basis: ProtocolDoseBasis
    @State private var minDose: String
    @State private var maxDose: String
    @State private var frequency: String
    @State private var route: String
    @State private var strengthsText: String
    @State private var concentration: String
    @State private var sourceReference: String
    @State private var notes: String
    @State private var approved: Bool

    init(
        medication: Medication,
        species: Species,
        store: ProtocolMedicationStore,
        seed: ProtocolMedicationDefinition? = nil
    ) {
        self.medication = medication
        self.species = species
        self.store = store
        self.seed = seed
        let saved = store.definition(for: medication, species: species)
        let existing = saved ?? seed
        _basis = State(initialValue: existing?.doseBasis ?? .mgKg)
        _minDose = State(initialValue: existing.map { MedicationSafety.input($0.minDose) } ?? "")
        _maxDose = State(initialValue: existing.flatMap { $0.maxDose > 0 ? MedicationSafety.input($0.maxDose) : nil } ?? "")
        _frequency = State(initialValue: existing?.frequency ?? "")
        _route = State(initialValue: existing?.route ?? "")
        _strengthsText = State(initialValue: existing?.strengths.map(MedicationSafety.input).joined(separator: ", ") ?? "")
        _concentration = State(initialValue: existing?.concentration.map(MedicationSafety.input) ?? "")
        _sourceReference = State(initialValue: existing?.sourceReference ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
        _approved = State(initialValue: saved?.veterinarianApproved == true && saved?.validationIssue == nil)
    }

    private var parsedStrengths: [Double] {
        strengthsText
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0 > 0 }
    }

    private var valid: Bool {
        let pieces = strengthsText.split(separator: ",", omittingEmptySubsequences: false)
        let strengthListValid = strengthsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            pieces.allSatisfy { MedicationSafety.parsePositive(String($0)) != nil }
        return MedicationSafety.enteredRangeIsValid(low: minDose, high: maxDose, concentration: concentration) &&
            strengthListValid && approved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    LabeledContent("Medication", value: medication.displayName)
                    LabeledContent("Species", value: species.rawValue)
                    Text(medication.indication)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if seed != nil, store.definition(for: medication, species: species) == nil {
                    Section("Starting point") {
                        Label("Prefilled from the selected built-in veterinary reference protocol", systemImage: "doc.text.magnifyingglass")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.blue)
                        Text("Saving creates a clinic override. The built-in reference remains available again if the override is disabled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Clinic dose equation") {
                    Picker("Dose basis", selection: $basis) {
                        ForEach(ProtocolDoseBasis.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    TextField("Minimum dose", text: $minDose)
                        .keyboardType(.decimalPad)
                    TextField("Maximum dose (optional)", text: $maxDose)
                        .keyboardType(.decimalPad)
                    TextField("Frequency, e.g. q12h", text: $frequency)
                    TextField("Route, e.g. PO / IV / SC", text: $route)
                }

                if basis.supportsStrength {
                    Section("Tablet / capsule strengths") {
                        TextField("mg strengths, comma separated", text: $strengthsText)
                            .keyboardType(.numbersAndPunctuation)
                        Text("Leave blank if the product is not dosed by tablet/capsule strength.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if basis.supportsConcentration {
                    Section("Liquid / injectable concentration — \(basis.concentrationLabel)") {
                        TextField(basis.concentrationLabel, text: $concentration)
                            .keyboardType(.decimalPad)
                        Text("Enter the concentration in exactly \(basis.concentrationLabel). VetPilot uses this only for mathematical volume conversion. Verify the product label or pharmacy concentration before administration.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Protocol reference / notes") {
                    TextField("Clinic protocol, formulary, label, URL… (optional)", text: $sourceReference, axis: .vertical)
                    TextField("Safety / monitoring notes (optional)", text: $notes, axis: .vertical)
                }

                Section("Enable clinic override") {
                    Toggle("Veterinarian / clinic has reviewed this dose rule", isOn: $approved)
                    Text("This enables arithmetic only. It does not make the entered dose appropriate for every indication or patient.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if store.definition(for: medication, species: species) != nil {
                    Section {
                        Button("Disable clinic override", role: .destructive) {
                            store.remove(for: medication, species: species)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Clinic protocol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard valid, let low = MedicationSafety.parsePositive(minDose) else { return }
                        let high = Double(maxDose) ?? low
                        let def = ProtocolMedicationDefinition(
                            medicationKey: ProtocolMedicationDefinition.key(for: medication, species: species),
                            generic: medication.generic,
                            speciesRaw: species.rawValue,
                            doseBasisRaw: basis.rawValue,
                            minDose: low,
                            maxDose: high > 0 ? high : low,
                            frequency: frequency.trimmingCharacters(in: .whitespacesAndNewlines),
                            route: route.trimmingCharacters(in: .whitespacesAndNewlines),
                            strengths: parsedStrengths,
                            concentration: Double(concentration),
                            sourceReference: sourceReference,
                            notes: notes,
                            veterinarianApproved: approved
                        )
                        store.save(def)
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
        }
    }
}
