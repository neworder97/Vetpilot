import XCTest
@testable import FergusonVetPilot

@MainActor final class ClinicSyncTests: XCTestCase {
    func sample(_ title: String = "Original") -> ClinicProtocol {
        var item = ClinicProtocol(); item.title = title; return item
    }
    func testRemoteEditsAndDeletion() {
        let base = sample(); var remote = base; remote.notes = "Website edit"
        XCTAssertEqual(ClinicMerge.merge(local: [base], base: [base], remote: [remote]), [remote])
        XCTAssertTrue(ClinicMerge.merge(local: [base], base: [base], remote: []).isEmpty)
        XCTAssertTrue(ClinicMerge.merge(local: [], base: [base], remote: [base]).isEmpty)
    }
    func testConcurrentEditsPreserveBothAndClearCopyReview() {
        let base = sample(); var local = base; var remote = base
        local.notes = "App edit"; local.reviewer = "Reviewer"; remote.notes = "Web edit"
        let merged = ClinicMerge.merge(local: [local], base: [base], remote: [remote])
        XCTAssertEqual(merged.count, 2)
        XCTAssertTrue(merged.contains(remote))
        let copy = merged.first { $0.id != base.id }!
        XCTAssertEqual(copy.notes, "App edit"); XCTAssertEqual(copy.reviewer, "")
    }
    func testDeleteVersusEditNeverLosesEditedCopy() {
        let base = sample(); var local = base; local.notes = "Offline edit"
        let merged = ClinicMerge.merge(local: [local], base: [base], remote: [])
        XCTAssertEqual(merged.count, 1); XCTAssertNotEqual(merged[0].id, base.id)
        XCTAssertEqual(merged[0].notes, local.notes)
        XCTAssertEqual(ClinicMerge.merge(local: [], base: [base], remote: [local]), [local])
    }
    func testAccountFilesAndGuestAreSeparate() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ClinicStore(fileURL: folder.appendingPathComponent("guest.json"))
        try store.save(sample("Guest")); let a = UUID(), b = UUID()
        store.switchAccount(a); XCTAssertTrue(store.items.isEmpty); try store.save(sample("A"))
        store.switchAccount(b); XCTAssertTrue(store.items.isEmpty); try store.save(sample("B"))
        store.switchAccount(a); XCTAssertEqual(store.items.map(\.title), ["A"])
        store.switchAccount(nil); XCTAssertEqual(store.items.map(\.title), ["Guest"])
    }
    func testStaleEditorPreservesRemoteRevision() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ClinicStore(fileURL: folder.appendingPathComponent("guest.json"))
        try store.save(sample()); let base = store.items[0]
        var remote = base; remote.notes = "Remote"; try store.save(remote)
        var draft = base; draft.notes = "Local"; try store.save(draft, basedOn: base)
        XCTAssertEqual(store.items.count, 2)
        XCTAssertTrue(store.items.contains { $0.notes == "Remote" })
        XCTAssertTrue(store.items.contains { $0.notes == "Local" && $0.id != base.id })
    }

}
