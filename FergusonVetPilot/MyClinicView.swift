import SwiftUI
import UniformTypeIdentifiers

struct MyClinicView: View {
    @ObservedObject var store: ClinicStore
    @State private var search = ""
    @State private var filter = "All"
    @State private var category = "All categories"
    @State private var editor: ClinicProtocol?
    @State private var importing = false
    @State private var emailSettings = false
    @State private var sharing: ClinicShare?

    private var filtered: [ClinicProtocol] {
        store.items.filter {
            $0.matches(search) && (category == "All categories" || $0.category == category) &&
            (filter != "Favorites" || $0.favorite) && (filter != "Recent" || $0.lastOpened != nil)
        }.sorted {
            if filter == "Recent" { return ($0.lastOpened ?? .distantPast) > ($1.lastOpened ?? .distantPast) }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Procedures & Nursing").font(.headline).foregroundStyle(AppTheme.blue)
                    Text("Create your clinic's protocols and reusable equipment lists. Available offline; signed-in collections sync with the website every minute. Guest items stay local—export them before signing in, then import into your account.").font(.footnote)
                    if store.canCopyGuestItems {
                        Button("Copy this device's guest protocols into my account") {
                            do { try store.copyGuestItems() } catch { store.errorMessage = error.localizedDescription }
                        }
                    }
                    Text(store.syncStatus).font(.caption).accessibilityIdentifier("clinic.sync.status")
                    Picker("Show", selection: $filter) {
                        ForEach(["All", "Favorites", "Recent"], id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.segmented)
                    Picker("Category", selection: $category) {
                        Text("All categories").tag("All categories")
                        ForEach(Array(Set(ClinicProtocol.categories + store.items.map(\.category))).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                }
                if store.items.isEmpty {
                    Section {
                        ContentUnavailableView("Your clinic, your protocols", systemImage: "list.clipboard", description: Text("Start a protocol or equipment set, or import a teammate's .vetpilot file."))
                        Button("Create first item") { editor = ClinicProtocol() }
                            .accessibilityIdentifier("clinic.create.first")
                    }
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    Section("\(filtered.count) items") {
                        ForEach(filtered) { item in
                            NavigationLink {
                                ClinicDetailView(store: store, itemID: item.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(item.title).font(.headline)
                                        if item.favorite { Image(systemName: "star.fill").foregroundStyle(AppTheme.orange) }
                                    }
                                    Text("\(item.kind) • \(item.category) • v\(item.revision)").font(.caption).foregroundStyle(.secondary)
                                    Text("\(item.steps.count) steps • \(item.equipment.count) equipment items").font(.caption)
                                    if item.imported { Text("Imported copy • review before use").font(.caption).foregroundStyle(AppTheme.orange) }
                                }
                            }.accessibilityIdentifier("clinic.item.\(item.title)")
                        }
                    }
                }
                Section("Sharing") {
                    Button("Email, text & export settings") { emailSettings = true }
                        .accessibilityIdentifier("clinic.email.settings")
                    if !store.items.isEmpty {
                        ClinicEmailButton(items: store.items, pdf: true)
                        ClinicEmailButton(items: store.items, pdf: false)
                        ClinicTextButton(items: store.items, pdf: true)
                        ClinicTextButton(items: store.items, pdf: false)
                    }
                    Text(ClinicProtocol.reviewNotice).font(.caption).foregroundStyle(.secondary)
                    Text("Share copies with your team using PDF or an editable .vetpilot file. Changes do not sync between devices.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("My Clinic")
            .searchable(text: $search, prompt: "Search protocols, steps or equipment")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { importing = true } label: { Label("Import", systemImage: "square.and.arrow.down") }
                        .accessibilityIdentifier("clinic.import")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { emailSettings = true } label: { Label("Sharing settings", systemImage: "gearshape") }
                        .accessibilityIdentifier("clinic.sharing.settings")
                    Menu {
                        Button("Export all as PDF") { export(pdf: true) }
                        Button("Export all as editable file") { export(pdf: false) }
                    } label: { Label("Export", systemImage: "square.and.arrow.up") }
                    .disabled(store.items.isEmpty)
                    .accessibilityIdentifier("clinic.export.all")
                    Button { editor = ClinicProtocol() } label: { Label("New item", systemImage: "plus") }
                        .accessibilityIdentifier("clinic.new")
                }
            }
            .sheet(isPresented: $emailSettings) { ClinicEmailSettings() }
            .sheet(item: $editor) { item in ClinicEditorView(store: store, initial: item) }
            .sheet(item: $sharing) { ClinicShareSheet(urls: $0.urls) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.vetPilotProtocol, .json]) { result in
                switch result {
                case .success(let url): store.prepareImport(url)
                case .failure(let error): store.errorMessage = error.localizedDescription
                }
            }
            .sheet(item: $store.importPreview) { package in ClinicImportPreview(store: store, package: package) }
            .alert("My Clinic", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK", role: .cancel) { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
    }
    private func export(pdf: Bool) {
        do { sharing = ClinicShare(urls: [try ClinicTransfer.export(store.items, pdf: pdf)]) }
        catch { store.errorMessage = error.localizedDescription }
    }
}

struct ClinicImportPreview: View {
    @ObservedObject var store: ClinicStore
    let package: ClinicPackage
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Review before importing").font(.headline)
                    Text("\(package.items.count) items will be added as separate editable copies. Existing items are never replaced. Names, photos and reviewer details come from the sender and are not independently verified.")
                    Text(ClinicProtocol.reviewNotice).foregroundStyle(AppTheme.orange)
                }
                ForEach(package.items) { item in
                    Section(item.title) {
                        Text("\(item.category) • \(item.kind) • Version \(item.revision)")
                        Text("\(item.steps.count) steps • \(item.equipment.count) equipment items • \(item.photos.count) photos")
                        if !item.summary.isEmpty { Text(item.summary) }
                        if store.items.contains(where: { $0.id == item.id || $0.sourceID == item.id || $0.title.localizedCaseInsensitiveCompare(item.title) == .orderedSame }) {
                            Text("A matching item already exists. This import will add another copy.").foregroundStyle(AppTheme.orange)
                        }
                        ForEach(item.steps) { Text($0.text) }
                        ForEach(item.equipment) { Text("\($0.name) • \($0.quantity) • \($0.size) • \($0.location)") }
                        if !item.notes.isEmpty { Text(item.notes) }
                        if !item.author.isEmpty { Text("Author: \(item.author)") }
                        if !item.reviewer.isEmpty { Text("Reviewer (sender-entered): \(item.reviewer) • \(item.reviewedOn)") }
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Import preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import copies") {
                        do { try store.importCopies(package); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("clinic.import.confirm")
                }
            }
        }
    }
}

struct ClinicShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
