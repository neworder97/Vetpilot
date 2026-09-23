import XCTest
@testable import FergusonVetPilot

final class LabworkTests: XCTestCase {
    func testSearchByCodeProviderAndSpecimen() {
        XCTAssertEqual(LabworkCatalog.search("20011").map(\.id), ["MSU-20011"])
        XCTAssertEqual(LabworkCatalog.search("  msu   acth ").map(\.id), ["MSU-20006"])
        XCTAssertEqual(LabworkCatalog.search("michigan thyroid", provider: .idexx).count, 0)
        XCTAssertTrue(LabworkCatalog.search("lavender").contains { $0.id == "IDEXX-375" })
        XCTAssertTrue(LabworkCatalog.search("nonsense-test-code").isEmpty)
    }

    func testPreparationIsTestSpecific() throws {
        let acth = try XCTUnwrap(LabworkCatalog.tests.first { $0.id == "MSU-20006" })
        XCTAssertEqual(acth.specimen, "EDTA plasma")
        XCTAssertTrue(LabworkCatalog.preparation(acth.preparation).contains("Do not clot"))
        let thyroid = try XCTUnwrap(LabworkCatalog.tests.first { $0.id == "MSU-20011" })
        XCTAssertEqual(thyroid.amount, "2 mL")
        XCTAssertTrue(LabworkCatalog.preparation(thyroid.preparation).contains("30–60"))
        let cbc = try XCTUnwrap(LabworkCatalog.tests.first { $0.id == "MSU-11600" })
        XCTAssertTrue(cbc.notes.contains("half full"))
        XCTAssertTrue(cbc.notes.contains("Do not centrifuge"))
    }

    func testUnavailableTestsAreNeverGivenCollectionInstructions() {
        let unavailable = LabworkCatalog.tests.filter { !$0.available }
        XCTAssertEqual(Set(unavailable.map(\.code)), Set(["20004", "20030"]))
        XCTAssertTrue(unavailable.allSatisfy { $0.preparation == "unavailable" })
    }

    func testCatalogIntegrityAndOfficialSources() {
        XCTAssertEqual(LabworkCatalog.tests.count, 28)
        XCTAssertEqual(Set(LabworkCatalog.tests.map(\.id)).count, 28)
        for test in LabworkCatalog.tests {
            XCTAssertFalse(test.amount.isEmpty)
            XCTAssertFalse(test.purpose.isEmpty)
            XCTAssertEqual(URL(string: test.source)?.scheme, "https")
            XCTAssertTrue(["www.idexx.com", "cvm.msu.edu", "vdl.msu.edu"].contains(URL(string: test.source)?.host ?? ""))
        }
    }
}
