import XCTest
import PDFKit
import UIKit
@testable import FergusonVetPilot

@MainActor
final class ClinicTests: XCTestCase {
    private var directory: URL!
    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: directory); super.tearDown() }
    private func example() -> ClinicProtocol {
        var item = ClinicProtocol()
        item.title = "Exam preparation"; item.category = "Exams"; item.author = "Test author"
        item.steps = [ClinicStep(text: "Check room supplies"), ClinicStep(text: "Confirm equipment is ready")]
        item.equipment = [ClinicEquipment(name: "Stethoscope", quantity: "1", size: "Standard", location: "Exam room")]
        item.notes = "Clinic-specific instructions"; item.reviewer = "Reviewer"; item.reviewedOn = "2026-09-24"
        return item
    }
    func testRoundTripKeepsAllEditableFieldsAndPhotos() throws {
        var item = example()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { ctx in
            UIColor.blue.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        item.photos = [ClinicPhoto(caption: "Equipment", jpeg: image.jpegData(compressionQuality: 0.8)!)]
        let data = try ClinicPackage(items: [item]).encoded()
        let decoded = try ClinicPackage.decode(data)
        XCTAssertEqual(decoded.items[0].steps, item.steps)
        XCTAssertEqual(decoded.items[0].equipment, item.equipment)
        XCTAssertEqual(decoded.items[0].photos, item.photos)
        XCTAssertEqual(decoded.items[0].reviewer, item.reviewer)
        XCTAssertEqual(decoded.items[0].revision, item.revision)
        try ClinicTransfer.validatePhotos(decoded.items)
    }
    func testDuplicateImportsNeverOverwriteAndPersist() throws {
        let url = directory.appendingPathComponent("store.json")
        let store = ClinicStore(fileURL: url); let item = example()
        try store.save(item)
        let package = ClinicPackage(items: [item])
        try store.importCopies(package); try store.importCopies(package)
        XCTAssertEqual(store.items.count, 3)
        XCTAssertEqual(Set(store.items.map(\.id)).count, 3)
        XCTAssertEqual(store.items.filter(\.imported).count, 2)
        XCTAssertEqual(store.items[0].reviewer, "Reviewer")
        XCTAssertEqual(ClinicStore(fileURL: url).items.count, 3)
    }
    func testEditingRevisionsAndReviewResetAndFavoritePersistence() throws {
        let url = directory.appendingPathComponent("store.json"); let store = ClinicStore(fileURL: url)
        var item = example(); try store.save(item)
        store.toggleFavorite(item.id); store.opened(item.id)
        item = store.items[0]; item.steps[0].text = "Changed content"; try store.save(item)
        let loaded = ClinicStore(fileURL: url).items[0]
        XCTAssertEqual(loaded.revision, 2); XCTAssertTrue(loaded.favorite); XCTAssertNotNil(loaded.lastOpened)
        XCTAssertEqual(loaded.reviewer, ""); XCTAssertEqual(loaded.reviewedOn, "")
        var reviewed = loaded; reviewed.reviewer = "New reviewer"; reviewed.reviewedOn = "2026-09-25"
        try store.save(reviewed); XCTAssertEqual(store.items[0].reviewer, "New reviewer")
    }
    func testInvalidImportCannotChangeStore() throws {
        let store = ClinicStore(fileURL: directory.appendingPathComponent("store.json")); try store.save(example())
        let bad = directory.appendingPathComponent("bad.vetpilot"); try Data("not JSON".utf8).write(to: bad)
        store.prepareImport(bad); XCTAssertNil(store.importPreview); XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.items.count, 1)
        var future = ClinicPackage(items: [example()]); future.schemaVersion = 99
        XCTAssertThrowsError(try future.encoded())
        var duplicate = example(); duplicate.steps.append(duplicate.steps[0])
        XCTAssertThrowsError(try ClinicPackage(items: [duplicate]).encoded())
        XCTAssertThrowsError(try ClinicPackage.decode(Data(repeating: 0, count: ClinicPackage.maximumBytes + 1)))
    }
    func testCorruptStorePreservedWithoutOverwrite() throws {
        let url = directory.appendingPathComponent("store.json"); let data = Data("damaged".utf8); try data.write(to: url)
        let store = ClinicStore(fileURL: url)
        XCTAssertThrowsError(try store.save(example()))
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
    func testSearchFindsEquipmentLocationAndMultipleWords() {
        let item = example()
        XCTAssertTrue(item.matches("STETHOSCOPE room")); XCTAssertTrue(item.matches("preparation"))
        XCTAssertFalse(item.matches("stethoscope refrigerator"))
    }
    func testExportFilesAndProductionImportPreview() throws {
        let item = example()
        let file = try ClinicTransfer.export([item], pdf: false)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = ClinicStore(fileURL: directory.appendingPathComponent("store.json"))
        store.prepareImport(file)
        XCTAssertEqual(store.importPreview?.items.first?.title, item.title)
        XCTAssertTrue(store.items.isEmpty, "Preview must not mutate storage")
        try store.importCopies(XCTUnwrap(store.importPreview))
        XCTAssertEqual(store.items.count, 1)
        XCTAssertNotEqual(store.items[0].id, item.id)
    }
    func testMultiPagePDFPreservesLongTextAndFinalEquipment() throws {
        var item = example()
        item.notes = String(repeating: "Long reference note for layout testing. ", count: 250) + "END_OF_LONG_NOTES"
        let data = ClinicTransfer.makePDF([item, example()])
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(pdf.pageCount, 2)
        let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
        XCTAssertTrue(text.contains("END_OF_LONG_NOTES")); XCTAssertTrue(text.contains("Stethoscope"))
        XCTAssertTrue(text.contains("User-created protocol"))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "MyClinic-multipage-export.pdf"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
