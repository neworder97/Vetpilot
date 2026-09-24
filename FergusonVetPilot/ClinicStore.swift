import Foundation
import Combine

@MainActor
final class ClinicStore: ObservableObject {
    @Published private(set) var items: [ClinicProtocol] = []
    @Published var importPreview: ClinicPackage?
    @Published var errorMessage: String?
    private let fileURL: URL
    private var loadFailed = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VetPilot/MyClinic.json")
        do {
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
                items = try decoder.decode([ClinicProtocol].self, from: Data(contentsOf: self.fileURL))
                for item in items { _ = try item.validated() }
                guard Set(items.map(\.id)).count == items.count else { throw ClinicFileError.invalid("Duplicate stored item IDs.") }
            }
        } catch {
            items = []; loadFailed = true
            errorMessage = "My Clinic could not read its saved data. The original file has been preserved; saving is disabled to avoid overwriting it. \(error.localizedDescription)"
        }
    }

    private func commit(_ updated: [ClinicProtocol]) throws {
        guard !loadFailed else { throw ClinicFileError.invalid("Saved data needs recovery before changes can be saved.") }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(updated)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        items = updated
    }

    func save(_ item: ClinicProtocol) throws {
        var item = try item.validated()
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
