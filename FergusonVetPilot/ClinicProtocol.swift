import Foundation

struct ClinicStep: Codable, Equatable, Identifiable {
    var id = UUID()
    var text = ""
}

struct ClinicEquipment: Codable, Equatable, Identifiable {
    var id = UUID()
    var name = ""
    var quantity = ""
    var size = ""
    var location = ""
}

struct ClinicPhoto: Codable, Equatable, Identifiable {
    var id = UUID()
    var caption = ""
    var jpeg: Data
}

struct ClinicProtocol: Codable, Equatable, Identifiable {
    var id = UUID()
    var title = ""
    var category = "General"
    var kind = "Protocol"
    var summary = ""
    var steps: [ClinicStep] = []
    var equipment: [ClinicEquipment] = []
    var notes = ""
    var photos: [ClinicPhoto] = []
    var author = ""
    var reviewer = ""
    var reviewedOn = ""
    var revision = 1
    var updatedAt = Date()
    var favorite = false
    var lastOpened: Date?
    var imported = false
    var sourceID: UUID?

    static let kinds = ["Protocol", "Equipment set"]
    static let categories = ["General", "Exams", "Procedures", "Nursing", "Surgery", "Dentistry", "Laboratory", "Imaging", "Emergency"]
    static let reviewNotice = "User-created protocol — review before clinical use"

    func matches(_ query: String) -> Bool {
        let haystack = ([title, category, kind, summary, notes, author, reviewer] +
            steps.map(\.text) + equipment.flatMap { [$0.name, $0.quantity, $0.size, $0.location] } + photos.map(\.caption))
            .joined(separator: " ")
        return query.split(whereSeparator: \.isWhitespace).allSatisfy {
            haystack.localizedCaseInsensitiveContains(String($0))
        }
    }

    func validated() throws -> ClinicProtocol {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !copy.title.isEmpty else { throw ClinicFileError.invalid("Give this item a title.") }
        guard Self.kinds.contains(kind), revision > 0, revision < 1_000_000 else {
            throw ClinicFileError.invalid("Unsupported item type or version.")
        }
        let strings = [title, category, summary, notes, author, reviewer, reviewedOn] + steps.map(\.text) +
            equipment.flatMap { [$0.name, $0.quantity, $0.size, $0.location] } + photos.map(\.caption)
        guard strings.allSatisfy({ $0.utf8.count <= 20_000 }), title.count <= 200,
              steps.count <= 200, equipment.count <= 200, photos.count <= 8,
              Set(steps.map(\.id)).count == steps.count,
              Set(equipment.map(\.id)).count == equipment.count,
              Set(photos.map(\.id)).count == photos.count else {
            throw ClinicFileError.invalid("Item is too large or has duplicate step, equipment or photo IDs.")
        }
        guard photos.allSatisfy({ !$0.jpeg.isEmpty && $0.jpeg.count <= 2_000_000 }),
              photos.reduce(0, { $0 + $1.jpeg.count }) <= 8_000_000 else {
            throw ClinicFileError.invalid("Photos exceed the supported size. Use up to eight smaller photos.")
        }
        return copy
    }

    func importedCopy() -> ClinicProtocol {
        var copy = self
        copy.sourceID = sourceID ?? id
        copy.id = UUID()
        copy.imported = true
        copy.favorite = false
        copy.lastOpened = nil
        return copy
    }
}

enum ClinicFileError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let text): return text } }
}

struct ClinicPackage: Codable, Equatable, Identifiable {
    var id: String { "clinic-import-preview" }
    var format = "VetPilot.MyClinic"
    var schemaVersion = 1
    var exportedAt = Date()
    var items: [ClinicProtocol]

    static let maximumBytes = 15_000_000
    func encoded() throws -> Data {
        guard format == "VetPilot.MyClinic", schemaVersion == 1, !items.isEmpty, items.count <= 100, Set(items.map(\.id)).count == items.count else {
            throw ClinicFileError.invalid("Unsupported or empty VetPilot protocol file.")
        }
        for item in items { _ = try item.validated() }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw ClinicFileError.invalid("File exceeds 15 MB. Export fewer items or photos at a time.") }
        return data
    }
    static func decode(_ data: Data) throws -> ClinicPackage {
        guard data.count <= maximumBytes else { throw ClinicFileError.invalid("File exceeds 15 MB.") }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let package = try decoder.decode(ClinicPackage.self, from: data)
        _ = try package.encoded()
        guard Set(package.items.map(\.id)).count == package.items.count else {
            throw ClinicFileError.invalid("The file contains duplicate item IDs.")
        }
        return package
    }
}
