import Foundation
import Combine

@MainActor
final class ClinicStore: ObservableObject {
    @Published private(set) var items: [ClinicProtocol] = []
    @Published var importPreview: ClinicPackage?
    @Published var errorMessage: String?
    private var fileURL: URL
    private let guestURL: URL
    private let collection: String
    private var owner: UUID?
    private var generation = 0
    private var state = ClinicSyncState()
    var signedInForSync: Bool { owner != nil }
    @Published private(set) var syncing = false
    @Published private(set) var syncStatus = "Guest collection — stored on this device"
    private var usesEnvelope = false
    private var loadFailed = false

    init(fileURL: URL? = nil, collection: String = "clinic") {
        self.collection = collection
        let resolved = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(collection == "clinic" ? "VetPilot/MyClinic.json" : "VetPilot/Cytology/Library.json")
        self.fileURL = resolved; self.guestURL = resolved
        load()
    }
    private func load() {
        items = []; state = ClinicSyncState(); loadFailed = false
        do {
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
                let data = try Data(contentsOf: self.fileURL)
                if usesEnvelope { state = try decoder.decode(ClinicSyncState.self, from: data); items = state.items }
                else { items = try decoder.decode([ClinicProtocol].self, from: data) }
                guard Set(state.baseline.map(\.id)).count == state.baseline.count else { throw ClinicFileError.invalid("Duplicate baseline IDs.") }
                for item in state.baseline { _ = try item.validated() }
                for item in items { _ = try item.validated() }
                guard Set(items.map(\.id)).count == items.count else { throw ClinicFileError.invalid("Duplicate stored item IDs.") }
            }
        } catch {
            items = []; loadFailed = true
            errorMessage = "\(collection == "clinic" ? "My Clinic" : "Cytology") could not read its saved data. The original file has been preserved; saving is disabled to avoid overwriting it. \(error.localizedDescription)"
        }
    }

    private func commit(_ updated: [ClinicProtocol]) throws {
        guard !loadFailed else { throw ClinicFileError.invalid("Saved data needs recovery before changes can be saved.") }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        // Canonical second-resolution ISO dates match the website and cloud payload.
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let normalized = try decoder.decode([ClinicProtocol].self, from: encoder.encode(updated))
        var next = state; next.items = normalized
        let data: Data
        if usesEnvelope { data = try encoder.encode(next) } else { data = try encoder.encode(normalized) }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        items = normalized; state = next
    }

    var canCopyGuestItems: Bool { owner != nil && FileManager.default.fileExists(atPath: guestURL.path) }
    func copyGuestItems() throws {
        guard owner != nil else { return }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let guest = try decoder.decode([ClinicProtocol].self, from: Data(contentsOf: guestURL))
        try importCopies(ClinicPackage(items: guest))
    }
    func switchAccount(_ id: UUID?) {
        guard id != owner else { return }
        generation += 1; owner = id; syncing = false
        usesEnvelope = id != nil
        fileURL = id.map { guestURL.deletingLastPathComponent().appendingPathComponent("Accounts/" + $0.uuidString.lowercased() + "/MyClinicSync.json") } ?? guestURL
        importPreview = nil; errorMessage = nil; load()
        syncStatus = id == nil ? "Guest collection — stored on this device" : "Sync pending"
    }
    func sync(account: VetPilotAccount) async {
        guard !syncing, !loadFailed, let owner, account.userID == owner else { return }
        syncing = true; let epoch = generation
        defer { if epoch == generation { syncing = false } }
        syncStatus = "Syncing \(collection == "clinic" ? "My Clinic" : "Cytology")…"
        do {
            struct Row: Decodable { var version: Int; var items: [ClinicProtocol] }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let data = try await account.request(path: "rest/v1/\(collection)_collections?select=version,items")
            let rows = try decoder.decode([Row].self, from: data)
            guard epoch == generation, account.userID == owner else { return }
            let remote = rows.first?.items ?? []; let version = rows.first?.version ?? 0
            for item in remote { _ = try item.validated() }
            guard remote.count <= 1000, Set(remote.map(\.id)).count == remote.count else { throw ClinicFileError.invalid("Duplicate cloud protocol IDs.") }
            try ClinicTransfer.validatePhotos(remote)
            let merged = ClinicMerge.merge(local: items, base: state.baseline, remote: remote)
            let old = state; state.baseline = remote; state.version = version
            do { try commit(merged) } catch { state = old; throw error }
            if items != remote {
                let candidate = items
                let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
                let bytes = try encoder.encode(candidate)
                guard bytes.count <= 15_000_000 else { throw ClinicFileError.invalid("\(collection == "clinic" ? "My Clinic" : "Cytology") exceeds the 15 MB sync limit. Reduce photos and retry.") }
                let result = try await account.request(path: "rest/v1/rpc/save_\(collection)_collection", method: "POST", body: ["expected_version": version, "collection_items": try JSONSerialization.jsonObject(with: bytes)])
                guard epoch == generation, account.userID == owner else { return }
                let before = state; state.version = try JSONDecoder().decode(Int.self, from: result); state.baseline = candidate
                // Keep edits made during upload queued against the acknowledged baseline.
                do { try commit(items) } catch { state = before; throw error }
            }
            syncStatus = "\(collection == "clinic" ? "My Clinic" : "Cytology") synced " + Date().formatted(date: .omitted, time: .shortened)
        } catch { if epoch == generation { syncStatus = "\(collection == "clinic" ? "My Clinic" : "Cytology") sync pending — " + error.localizedDescription } }
    }

    func save(_ item: ClinicProtocol, basedOn original: ClinicProtocol? = nil) throws {
        var item = try item.validated()
        if let original, let current = items.first(where: { $0.id == item.id }), current != original {
            item.id = UUID(); item.sourceID = original.id; item.title = String(item.title.prefix(180)) + " (conflict copy)"
            item.reviewer = ""; item.reviewedOn = ""
        } else if let original, !items.contains(where: { $0.id == original.id }) {
            item.id = UUID(); item.sourceID = original.id; item.title = String(item.title.prefix(180)) + " (conflict copy)"
            item.reviewer = ""; item.reviewedOn = ""
        }
        try ClinicTransfer.validatePhotos([item])
        var updated = items
        if let index = updated.firstIndex(where: { $0.id == item.id }) {
            item.revision = updated[index].revision + 1
            item.updatedAt = Date()
            // Editing changes the reviewed content: keep attribution, clear prior review attestation.
            let old = updated[index]
            let contentChanged = item.title != old.title || item.kind != old.kind || item.category != old.category ||
                item.summary != old.summary || item.steps != old.steps || item.equipment != old.equipment ||
                item.notes != old.notes || item.photos != old.photos
            if contentChanged && item.reviewer == old.reviewer && item.reviewedOn == old.reviewedOn {
                item.reviewer = ""; item.reviewedOn = ""
            }
            updated[index] = item
        } else { updated.append(item) }
        try commit(updated)
    }

    func delete(_ id: UUID) throws { try commit(items.filter { $0.id != id }) }
    func toggleFavorite(_ id: UUID) {
        var updated = items
        guard let i = updated.firstIndex(where: { $0.id == id }) else { return }
        updated[i].favorite.toggle()
        do { try commit(updated) } catch { errorMessage = error.localizedDescription }
    }
    func opened(_ id: UUID) {
        var updated = items
        guard let i = updated.firstIndex(where: { $0.id == id }) else { return }
        updated[i].lastOpened = Date()
        do { try commit(updated) } catch { errorMessage = error.localizedDescription }
    }
    func importCopies(_ package: ClinicPackage) throws {
        _ = try package.encoded()
        try ClinicTransfer.validatePhotos(package.items)
        try commit(items + package.items.map { $0.importedCopy() })
        importPreview = nil
    }
    func prepareImport(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= ClinicPackage.maximumBytes else { throw ClinicFileError.invalid("File exceeds 15 MB.") }
            // Coordinated read supports iCloud Drive and other Files providers.
            var coordinationError: NSError?
            var readResult: Result<Data, Error>?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinated in
                readResult = Result { try Data(contentsOf: coordinated) }
            }
            if let coordinationError { throw coordinationError }
            guard let readResult else { throw ClinicFileError.invalid("Unable to read the selected file.") }
            let package = try ClinicPackage.decode(readResult.get())
            try ClinicTransfer.validatePhotos(package.items)
            importPreview = package
        } catch { errorMessage = "Import was not completed. \(error.localizedDescription) Select an editable .vetpilot file; PDFs are for reading only." }
    }
}
