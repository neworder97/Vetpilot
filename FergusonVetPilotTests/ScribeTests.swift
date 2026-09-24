import XCTest
import PDFKit
@testable import FergusonVetPilot

final class ScribeTests: XCTestCase {
    func make(_ names: [String] = ["Max", "Bella"]) throws -> ScribeEncounter {
        try ScribeEncounter.create(title: "Visit", patients: names.map { ScribePatient(name: $0) })
    }
    func testDecimalsNegationAndAmbiguousPatientSeparation() throws {
        var item = try make()
        item.transcript = "Max weighs 12.5 kg and takes 0.25 mL. Bella has no vomiting. She is tired. Max and Bella are here."
        item.draftFromTranscript()
        XCTAssertTrue(item.notes[0].subjective.contains("12.5 kg")); XCTAssertTrue(item.notes[0].subjective.contains("0.25 mL"))
        XCTAssertTrue(item.notes[1].subjective.contains("no vomiting")); XCTAssertFalse(item.notes[0].subjective.contains("Bella"))
        XCTAssertTrue(item.unassigned.contains("She is tired")); XCTAssertTrue(item.unassigned.contains("Max and Bella"))
        XCTAssertTrue(item.notes.allSatisfy { $0.objective.isEmpty && $0.assessment.isEmpty && $0.plan.isEmpty && $0.finalizedAt == nil })
    }
    func testNameBoundariesAndAliases() throws {
        XCTAssertFalse(ScribeEncounter.mentions("Max", in: "Maxine is well"))
        XCTAssertTrue(ScribeEncounter.mentions("Max", in: "Max's appetite is poor"))
        var patients = [ScribePatient(name: "Max"), ScribePatient(name: "Bella")]; patients[1].aliases = "Bell, B"
        var item = try ScribeEncounter.create(title: "", patients: patients)
        item.transcript = "Bell has diarrhea. Maxine is not a registered patient."
        item.draftFromTranscript(); XCTAssertTrue(item.notes[1].subjective.contains("diarrhea")); XCTAssertTrue(item.unassigned.contains("Maxine"))
    }
    func testDuplicateNamesAliasesAndEmptyPatientsAreRejected() throws {
        XCTAssertThrowsError(try make([])); XCTAssertThrowsError(try make(["Max", "max"]))
        var patients = [ScribePatient(name: "Max"), ScribePatient(name: "Bella")]; patients[1].aliases = "MAX"
        XCTAssertThrowsError(try ScribeEncounter.create(title: "", patients: patients))
        XCTAssertThrowsError(try make([""]))
    }
    func testEditsInvalidateReviewAndTranslation() throws {
        var note = SOAPNote(patientID: UUID()); note.subjective = "No vomiting."
        try note.finalize(reviewer: "Dr Test")
        note.translation = NoteTranslation(language: "Spanish", text: "Sin vómitos.", sourceText: note.plainText, reviewed: true)
        note.subjective = "Vomiting today."; note.edited()
        XCTAssertNil(note.finalizedAt); XCTAssertNil(note.translation); XCTAssertTrue(note.reviewer.isEmpty)
    }
    func testCloudRejectsWrongPatientAndHistoryOnlyCannotFillOtherFields() throws {
        let item = try make(["Max"])
        var draft = ScribeCloudDraft(notes: [.init(patientID: UUID(), subjective: "History", objective: "Normal", assessment: "Disease", plan: "Drug")], unassigned: "", warnings: [])
        XCTAssertThrowsError(try draft.applying(to: item))
        draft.notes[0].patientID = item.patients[0].id
        let result = try draft.applying(to: item)
        XCTAssertTrue(result.notes[0].objective.isEmpty); XCTAssertTrue(result.notes[0].assessment.isEmpty); XCTAssertTrue(result.notes[0].plan.isEmpty)
    }
    func testUnassignedMoveRemovesFinalization() throws {
        var item = try make(); item.unassigned = "The doctor confirms this belongs to Max."
        item.notes[0].subjective = "Prior history"; try item.notes[0].finalize(reviewer: "Dr Test")
        try item.assignUnresolved(to: item.patients[0].id)
        XCTAssertTrue(item.unassigned.isEmpty); XCTAssertNil(item.notes[0].finalizedAt); XCTAssertTrue(item.notes[0].subjective.contains("confirms"))
    }
    func testRejectsAudioTraversalAndMissingPatientNotes() throws {
        var item = try make(); item.recordingFiles = ["../secret.m4a"]
        XCTAssertThrowsError(try item.validated()); item.recordingFiles = []; item.notes.removeLast()
        XCTAssertThrowsError(try item.validated())
    }
    @MainActor func testPersistenceAccountIsolationAndCorruptionPreservation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScribeStore(root: root); let item = try make(["Guest Max"]); try store.save(item)
        let user = UUID(); try store.switchAccount(user); XCTAssertTrue(store.encounters.isEmpty)
        try store.save(make(["Account Bella"])); try store.switchAccount(nil); XCTAssertEqual(store.encounters.first?.title, item.title)
        XCTAssertEqual(store.encounters.first?.patients.first?.name, "Guest Max")
        let file = root.appendingPathComponent("guest/encounters.json"); try Data("corrupt".utf8).write(to: file)
        let recovered = ScribeStore(root: root); XCTAssertThrowsError(try recovered.save(item)); XCTAssertEqual(try String(contentsOf: file), "corrupt")
    }
    @MainActor func testTranscriptEditClearsPriorReview() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: root) }
        let store = ScribeStore(root: root); var item = try make(["Max"]); item.notes[0].subjective = "Original"; try item.notes[0].finalize(reviewer: "Dr Test"); try store.save(item)
        item.transcript = "A corrected transcript"; try store.save(item)
        XCTAssertNil(store.encounters[0].notes[0].finalizedAt)
    }
    @MainActor func testLongUnicodePDFAndTranslationReviewGate() throws {
        var item = try make(["Milo 🐕"]); let id = item.patients[0].id
        item.notes[0].subjective = Array(repeating: "No vomiting. Dose 0.25 mL; weight 12.5 kg. μg/m² — history.", count: 600).joined(separator: "\n")
        let data = try ScribePDF.data(encounter: item, patientID: id, translated: false)
        let document = try XCTUnwrap(PDFDocument(data: data)); XCTAssertGreaterThan(document.pageCount, 5)
        let text = document.string ?? ""; XCTAssertTrue(text.contains("DRAFT")); XCTAssertTrue(text.contains("0.25 mL")); XCTAssertTrue(text.contains("12.5 kg"))
        item.notes[0].translation = NoteTranslation(language: "Spanish", text: "Sin vómitos.", sourceText: item.notes[0].plainText)
        XCTAssertThrowsError(try ScribePDF.data(encounter: item, patientID: id, translated: true))
        item.notes[0].translation?.reviewed = true
        XCTAssertNoThrow(try ScribePDF.data(encounter: item, patientID: id, translated: true))
        item.notes[0].subjective = "Changed"
        XCTAssertThrowsError(try ScribePDF.data(encounter: item, patientID: id, translated: true))
    }
}
