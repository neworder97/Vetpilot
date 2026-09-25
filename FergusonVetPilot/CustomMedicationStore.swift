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

    var hasValidDefinition: Bool {
        Species(rawValue: speciesRaw) != nil && MedicationForm(rawValue: formRaw) != nil &&
        CustomDoseBasis(rawValue: doseBasisRaw) != nil &&
        MedicationSafety.validRange(low: minDose, high: maxDose) && maxDose >= minDose && form != .any && MedicationSafety.optionalPositive(concentration)
    }

    var asMedication: Medication {
        Medication(
            generic: generic.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
            drugClass: drugClass.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom" : drugClass,
            species: [species],
            form: form,
            indication: indication.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom indication" : indication,
            kind: hasValidDefinition ? doseBasis.doseKind : .protocolOnly,
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

struct CustomMedicationSyncState: Codable {
    var items: [CustomMedicationDefinition] = []
    var baseline: [CustomMedicationDefinition] = []
    var version = 0
}

enum CustomMedicationMerge {
    static func merge(local: [CustomMedicationDefinition], base: [CustomMedicationDefinition], remote: [CustomMedicationDefinition]) -> [CustomMedicationDefinition] {
        let l = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        let b = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        let r = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
        var result: [CustomMedicationDefinition] = []
        for id in Set(l.keys).union(b.keys).union(r.keys).sorted(by: { $0.uuidString < $1.uuidString }) {
            if l[id] == b[id] { if let value = r[id] { result.append(value) } }
            else if r[id] == b[id] || l[id] == r[id] { if let value = l[id] { result.append(value) } }
            else {
                if let value = r[id] { result.append(value) }
                if var copy = l[id] { copy.id = UUID(); copy.generic += " (conflict copy)"; result.append(copy) }
            }
        }
        return result
    }
}

@MainActor
final class CustomMedicationStore: ObservableObject {
    @Published private(set) var definitions: [CustomMedicationDefinition] = []
    @Published private(set) var syncStatus = "Guest medications — stored on this device"
    @Published private(set) var syncing = false
    @Published private(set) var ready = true
    private let legacyKey = "ferguson.vetpilot.custom-medications.v1"
    private var key: String { owner.map { "ferguson.vetpilot.custom-medications.account." + $0.uuidString.lowercased() } ?? legacyKey }
    private var owner: UUID?
    private var generation = 0
    private var state = CustomMedicationSyncState()
    var signedIn: Bool { owner != nil }
    var canCopyGuest: Bool { owner != nil && UserDefaults.standard.data(forKey: legacyKey) != nil }
    init() { load() }
    private func validate(_ values: [CustomMedicationDefinition]) throws {
        guard values.count <= 500, Set(values.map(\.id)).count == values.count,
              values.allSatisfy({ $0.hasValidDefinition && !$0.generic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && [$0.generic,$0.brand,$0.drugClass,$0.indication,$0.frequency,$0.route,$0.sourceReference,$0.notes].allSatisfy { $0.count <= 20000 } }) else { throw ClinicFileError.invalid("Invalid custom medication collection; original data was preserved.") }
    }
    private func load() {
        state = CustomMedicationSyncState(); definitions = []; ready = false
        do {
            if let data = UserDefaults.standard.data(forKey: key) {
                if owner == nil { state.items = try JSONDecoder().decode([CustomMedicationDefinition].self, from: data) }
                else { state = try JSONDecoder().decode(CustomMedicationSyncState.self, from: data) }
            }
            try validate(state.items); try validate(state.baseline)
            guard state.version >= 0 else { throw ClinicFileError.invalid("Invalid sync revision") }
            definitions = state.items; ready = true
        } catch { syncStatus = "Saved medications need recovery. Original data was preserved." }
    }
    private func commit(_ next: CustomMedicationSyncState) throws {
        guard ready else { throw ClinicFileError.invalid("Saved medications need recovery") }
        try validate(next.items)
        let encoder = JSONEncoder()
        let data = owner == nil ? try encoder.encode(next.items) : try encoder.encode(next)
        UserDefaults.standard.set(data, forKey: key)
        state = next; definitions = next.items
    }
    func switchAccount(_ id: UUID?) {
        guard id != owner else { return }
        generation += 1; owner = id; syncing = false
        syncStatus = id == nil ? "Guest medications — stored on this device" : "Medication sync pending"
        load()
    }
    func add(_ definition: CustomMedicationDefinition) {
        var next = state; next.items.append(definition)
        do { try commit(next); syncStatus = "Saved locally — sync pending" } catch { syncStatus = error.localizedDescription }
    }
    func remove(at offsets: IndexSet) {
        var next = state; next.items.remove(atOffsets: offsets)
        do { try commit(next); syncStatus = "Saved locally — sync pending" } catch { syncStatus = error.localizedDescription }
    }
    func copyGuest() {
        guard canCopyGuest, let data = UserDefaults.standard.data(forKey: legacyKey) else { return }
        do {
            let guest = try JSONDecoder().decode([CustomMedicationDefinition].self, from: data); try validate(guest)
            var next = state
            let existing = Set(next.items.map(\.id))
            next.items += guest.filter { !existing.contains($0.id) }
            try commit(next); syncStatus = "Device medications copied — sync pending"
        } catch { syncStatus = error.localizedDescription }
    }
    func sync(account: VetPilotAccount) async {
        guard ready, !syncing, let owner, account.userID == owner else { return }
        syncing = true; let epoch = generation
        defer { if epoch == generation { syncing = false } }
        syncStatus = "Syncing custom medications…"
        do {
            struct Row: Decodable { var version: Int; var items: [CustomMedicationDefinition] }
            let data = try await account.request(path: "rest/v1/medication_collections?select=version,items")
            let rows = try JSONDecoder().decode([Row].self, from: data)
            guard epoch == generation, account.userID == owner else { return }
            let remote = rows.first?.items ?? []; let version = rows.first?.version ?? 0
            guard rows.count <= 1, version >= 0 else { throw ClinicFileError.invalid("Invalid medication revision") }
            try validate(remote)
            let merged = CustomMedicationMerge.merge(local: definitions, base: state.baseline, remote: remote)
            try commit(CustomMedicationSyncState(items: merged, baseline: remote, version: version))
            if merged != remote {
                let bytes = try JSONEncoder().encode(merged)
                guard bytes.count <= 2_000_000 else { throw ClinicFileError.invalid("Custom medications exceed the 2 MB sync limit") }
                let result = try await account.request(path: "rest/v1/rpc/save_medication_collection", method: "POST", body: ["expected_version": version, "collection_items": try JSONSerialization.jsonObject(with: bytes)])
                guard epoch == generation, account.userID == owner else { return }
                let ack = try JSONDecoder().decode(Int.self, from: result)
                guard ack == version + 1 else { throw ClinicFileError.invalid("Invalid sync acknowledgement") }
                try commit(CustomMedicationSyncState(items: definitions, baseline: merged, version: ack))
            }
            syncStatus = "Medications synced " + Date().formatted(date: .omitted, time: .shortened)
        } catch { if epoch == generation { syncStatus = "Medication sync pending — " + error.localizedDescription } }
    }
}

struct CustomMedicationManagerView: View {
    @ObservedObject var store: CustomMedicationStore
    @EnvironmentObject private var account: VetPilotAccount
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Custom calculators can run automatic math from an equation you enter. Adding a reference changes the badge to user source-backed, but only built-in researched entries carry the app's verified-source badge.")
                        .font(.footnote)
                }

                Section("Account sync") {
                    Text(store.syncStatus).font(.footnote)
                    Text("Signed-in custom medications sync with the website every 30 seconds while the app is active. Background sync runs when iOS allows.").font(.caption)
                    Button("Sync medications now") { Task { await store.sync(account: account) } }
                        .disabled(!store.signedIn || store.syncing || !store.ready)
                    if store.canCopyGuest { Button("Copy existing device medications to this account") { store.copyGuest() } }
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
                        Label("Add medication", systemImage: "plus")
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
        MedicationSafety.enteredRangeIsValid(low: minDose, high: maxDose, concentration: concentration)
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
                        guard valid, let low = MedicationSafety.parsePositive(minDose) else { return }
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
                    .disabled(!valid || !store.ready)
                }
            }
        }
    }
}
