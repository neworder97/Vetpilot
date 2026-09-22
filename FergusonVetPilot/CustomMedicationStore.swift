import SwiftUI

enum CustomDoseBasis: String, CaseIterable, Identifiable, Codable {
    case mgKg = "mg/kg"
    case mgLb = "mg/lb"
    case fixedMg = "Fixed mg"

    var id: String { rawValue }

    var doseKind: DoseKind {
        switch self {
        case .mgKg: return .mgKg
        case .mgLb: return .mgLb
        case .fixedMg: return .fixedMg
        }
    }
}

struct CustomMedicationDefinition: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var generic: String
    var brand: String
    var drugClass: String
    var speciesRaw: String
    var formRaw: String
    var indication: String
    var doseBasisRaw: String
    var minDose: Double
    var maxDose: Double
    var frequency: String
    var route: String
    var concentration: Double?
    var sourceReference: String
    var notes: String

    var species: Species { Species(rawValue: speciesRaw) ?? .dog }
    var form: MedicationForm { MedicationForm(rawValue: formRaw) ?? .tablet }
    var doseBasis: CustomDoseBasis { CustomDoseBasis(rawValue: doseBasisRaw) ?? .mgKg }
    var isSourceBacked: Bool { !sourceReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var asMedication: Medication {
        Medication(
            generic: generic.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
            drugClass: drugClass.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom" : drugClass,
            species: [species],
            form: form,
            indication: indication.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom indication" : indication,
            kind: doseBasis.doseKind,
            minDose: minDose,
            maxDose: maxDose > 0 ? maxDose : minDose,
            frequency: frequency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "per entered protocol" : frequency,
            route: route.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: customWarning,
            source: isSourceBacked
                ? "USER-SOURCE-BACKED • \(sourceReference.trimmingCharacters(in: .whitespacesAndNewlines))"
                : "CUSTOM-UNVERIFIED • No source attached",
            strengths: [],
            concentration: concentration,
            controlled: false
        )
    }

    private var customWarning: String {
        let base = isSourceBacked
            ? "User-entered calculator with a source attached. The app has not independently authenticated that source or equation."
            : "User-entered, unverified calculator. Equation has not been independently verified."
        let extra = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return extra.isEmpty ? base : base + " " + extra
    }
}

@MainActor
final class CustomMedicationStore: ObservableObject {
    @Published private(set) var definitions: [CustomMedicationDefinition] = []

    private let key = "ferguson.vetpilot.custom-medications.v1"

    init() {
        load()
    }

    func add(_ definition: CustomMedicationDefinition) {
        definitions.append(definition)
        save()
    }

    func remove(at offsets: IndexSet) {
        definitions.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CustomMedicationDefinition].self, from: data) else {
            definitions = []
            return
        }
        definitions = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(definitions) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct CustomMedicationManagerView: View {
    @ObservedObject var store: CustomMedicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Custom calculators can run automatic math from an equation you enter. Adding a reference changes the badge to user source-backed, but only built-in researched entries carry the app's verified-source badge.")
                        .font(.footnote)
                }

                Section("Saved custom medications") {
                    if store.definitions.isEmpty {
                        Text("No custom medications yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.definitions) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.brand.isEmpty ? item.generic : "\(item.generic) (\(item.brand))")
                                    .font(.headline)
                                Text("\(item.speciesRaw) • \(item.doseBasisRaw) • \(item.frequency)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.isSourceBacked ? "USER SOURCE-BACKED" : "CUSTOM / UNVERIFIED")
                                    .font(.caption2.bold())
                                    .foregroundStyle(item.isSourceBacked ? AppTheme.blue : AppTheme.orange)
                            }
                        }
                        .onDelete(perform: store.remove)
                    }
                }
            }
            .navigationTitle("Custom medications")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditor = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                CustomMedicationEditorView(store: store)
            }
        }
    }
}

private struct CustomMedicationEditorView: View {
    @ObservedObject var store: CustomMedicationStore
    @Environment(\.dismiss) private var dismiss

    @State private var generic = ""
    @State private var brand = ""
    @State private var drugClass = ""
    @State private var species: Species = .dog
    @State private var form: MedicationForm = .tablet
    @State private var indication = ""
    @State private var doseBasis: CustomDoseBasis = .mgKg
    @State private var minDose = ""
    @State private var maxDose = ""
    @State private var frequency = ""
    @State private var route = "PO"
    @State private var concentration = ""
    @State private var sourceReference = ""
    @State private var notes = ""

    private var valid: Bool {
        !generic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (Double(minDose) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Generic name", text: $generic)
                    TextField("Brand (optional)", text: $brand)
                    TextField("Drug class (optional)", text: $drugClass)
                    Picker("Species", selection: $species) {
                        ForEach(Species.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Form", selection: $form) {
                        ForEach(MedicationForm.allCases.filter { $0 != .any }) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Indication / use", text: $indication)
                }

                Section("Equation") {
                    Picker("Dose basis", selection: $doseBasis) {
                        ForEach(CustomDoseBasis.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Minimum dose", text: $minDose)
                        .keyboardType(.decimalPad)
                    TextField("Maximum dose (optional)", text: $maxDose)
                        .keyboardType(.decimalPad)
                    TextField("Frequency, e.g. q12h", text: $frequency)
                    TextField("Route, e.g. PO", text: $route)

                    if [.liquid, .injection, .transdermal].contains(form) {
                        TextField("Concentration mg/mL (optional)", text: $concentration)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Source / verification") {
                    TextField("Source, URL, formulary, paper, label…", text: $sourceReference, axis: .vertical)
                    Text(sourceReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? "No source attached: this will be labeled CUSTOM / UNVERIFIED."
                         : "A source is attached: this will be labeled USER SOURCE-BACKED. The app does not independently authenticate custom sources.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Notes") {
                    TextField("Safety notes / constraints", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("New custom medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let low = Double(minDose) ?? 0
                        let high = Double(maxDose) ?? low
                        let conc = Double(concentration)
                        store.add(CustomMedicationDefinition(
                            generic: generic,
                            brand: brand,
                            drugClass: drugClass,
                            speciesRaw: species.rawValue,
                            formRaw: form.rawValue,
                            indication: indication,
                            doseBasisRaw: doseBasis.rawValue,
                            minDose: low,
                            maxDose: high,
                            frequency: frequency,
                            route: route,
                            concentration: conc,
                            sourceReference: sourceReference,
                            notes: notes
                        ))
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
        }
    }
}
