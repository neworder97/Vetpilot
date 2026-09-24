import Foundation

enum ScribeError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

struct ScribePatient: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var species = "Dog"
    var reference = ""
    var aliases = ""
    var spokenNames: [String] {
        ([name] + aliases.split(separator: ",").map(String.init))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

struct SOAPNote: Codable, Identifiable, Equatable {
    var id = UUID()
    var patientID: UUID
    var subjective = ""
    var objective = ""
    var assessment = ""
    var plan = ""
    var reviewer = ""
    var finalizedAt: Date?
    var updatedAt = Date()
    var translation: NoteTranslation?
    var hasContent: Bool { [subjective, objective, assessment, plan].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    var plainText: String { "SUBJECTIVE / HISTORY\n\(subjective)\n\nOBJECTIVE\n\(objective)\n\nASSESSMENT\n\(assessment)\n\nPLAN\n\(plan)" }
    mutating func edited() { finalizedAt = nil; reviewer = ""; translation = nil; updatedAt = Date() }
    mutating func finalize(reviewer: String) throws {
        let name = reviewer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, hasContent else { throw ScribeError.invalid("Enter the reviewing clinician's name and review the note before finalizing.") }
        self.reviewer = name; finalizedAt = Date(); updatedAt = Date()
    }
}

struct NoteTranslation: Codable, Equatable {
    var language: String
    var text: String
    var sourceText: String
    var reviewed = false
}

struct ScribeEncounter: Codable, Identifiable, Equatable {
    var id = UUID()
    var createdAt = Date()
    var updatedAt = Date()
    var title: String
    var patients: [ScribePatient]
    var consentAt: Date?
    var recordingFiles: [String] = []
    var recordedSeconds: Double = 0
    var transcript = ""
    var unassigned = ""
    var notes: [SOAPNote] = []
    var processingMethod = "Manual entry"
    var historyOnly = true
    var locale = "en-US"
    var reviewFlags: [String] = []
    var syncVersion = 0
    var syncedAt: Date?

    static func create(title: String, patients: [ScribePatient], historyOnly: Bool = true) throws -> Self {
        guard (1...8).contains(patients.count) else { throw ScribeError.invalid("Add between one and eight patients.") }
        var names = Set<String>()
        for patient in patients {
            guard !patient.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, patient.name.count <= 80 else {
                throw ScribeError.invalid("Each patient needs a name of up to 80 characters.")
            }
            for name in patient.spokenNames {
                let normalized = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                guard names.insert(normalized).inserted else { throw ScribeError.invalid("Use distinct patient names and aliases. For pets with the same name, add a unique spoken label.") }
            }
        }
        var value = Self(title: title.isEmpty ? patients.map(\.name).joined(separator: " & ") : title, patients: patients)
        value.historyOnly = historyOnly
        value.notes = patients.map { SOAPNote(patientID: $0.id) }
        return value
    }

    func validated() throws -> Self {
        _ = try Self.create(title: title, patients: patients)
        guard Set(patients.map(\.id)).count == patients.count,
              Set(notes.map(\.patientID)).count == notes.count,
              notes.count == patients.count, notes.allSatisfy({ note in patients.contains { $0.id == note.patientID } }),
              transcript.count <= 200_000, unassigned.count <= 200_000,
              notes.allSatisfy({ $0.plainText.count <= 200_000 }),
              recordedSeconds.isFinite, recordedSeconds >= 0,
              recordingFiles.allSatisfy({ $0 == URL(fileURLWithPath: $0).lastPathComponent && $0.hasSuffix(".m4a") && !$0.contains("..") }) else {
            throw ScribeError.invalid("The encounter contains invalid or oversized data.")
        }
        return self
    }

    // Offline mode copies only explicit sentences; it does not infer diagnoses,
    // speaker identity, negation, or pronoun ownership across sentences.
    mutating func draftFromTranscript() {
        notes = patients.map { SOAPNote(patientID: $0.id) }
        var unresolved: [String] = []
        let sentences = transcript.replacingOccurrences(of: "(?<=[.!?])\\s+|\\n+", with: "\u{001E}", options: .regularExpression).components(separatedBy: "\u{001E}")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for sentence in sentences {
            let matches = patients.filter { patient in patient.spokenNames.contains { Self.mentions($0, in: sentence) } }
            if matches.count == 1, let index = notes.firstIndex(where: { $0.patientID == matches[0].id }) {
                notes[index].subjective += (notes[index].subjective.isEmpty ? "" : "\n") + sentence
            } else if patients.count == 1, matches.isEmpty {
                notes[0].subjective += (notes[0].subjective.isEmpty ? "" : "\n") + sentence
            } else { unresolved.append(sentence) }
        }
        unassigned = unresolved.joined(separator: "\n")
        processingMethod = "On-device transcript / verbatim history draft"
        reviewFlags = ["Review the transcript, patient attribution, negations, medical terms, numbers and units. Offline drafting does not interpret clinical meaning."]
        if !historyOnly { reviewFlags.append("Move clinician-supplied findings, assessment and plan into the appropriate SOAP fields. Empty fields mean not documented.") }
        updatedAt = Date()
    }

    static func mentions(_ name: String, in sentence: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        return sentence.range(of: "(?<![\\p{L}\\p{N}])" + escaped + "(?![\\p{L}\\p{N}])", options: [.regularExpression, .caseInsensitive, .diacriticInsensitive]) != nil
    }

    mutating func assignUnresolved(to patientID: UUID) throws {
        guard let index = notes.firstIndex(where: { $0.patientID == patientID }), !unassigned.isEmpty else { return }
        notes[index].subjective += (notes[index].subjective.isEmpty ? "" : "\n") + unassigned
        notes[index].edited(); unassigned = ""; updatedAt = Date()
    }
}

struct ScribeCloudDraft: Codable {
    struct PatientNote: Codable {
        var patientID: UUID
        var subjective: String
        var objective: String
        var assessment: String
        var plan: String
    }
    var notes: [PatientNote]
    var unassigned: String
    var warnings: [String]
    func applying(to encounter: ScribeEncounter) throws -> ScribeEncounter {
        guard notes.count == encounter.patients.count, Set(notes.map(\.patientID)) == Set(encounter.patients.map(\.id)),
              Set(notes.map(\.patientID)).count == notes.count else { throw ScribeError.invalid("AI returned a missing, duplicate or unknown patient. The original transcript is preserved.") }
        var result = encounter
        result.notes = notes.map { item in
            var note = SOAPNote(patientID: item.patientID)
            note.subjective = item.subjective
            if !encounter.historyOnly { note.objective = item.objective; note.assessment = item.assessment; note.plan = item.plan }
            return note
        }
        result.unassigned = unassigned; result.reviewFlags = warnings
        result.processingMethod = "Cloud AI draft — clinician review required"; result.updatedAt = Date()
        return try result.validated()
    }
}
