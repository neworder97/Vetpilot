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
        XCTAssertEqual(LabworkCatalog.tests.count, 42)
        XCTAssertEqual(Set(LabworkCatalog.tests.map(\.id)).count, 42)
        XCTAssertEqual(LabworkCatalog.tests.filter { $0.provider == "IDEXX" }.count, 29)
        XCTAssertEqual(LabworkCatalog.tests.filter { $0.provider == "MSU" }.count, 13)
        for test in LabworkCatalog.tests {
            XCTAssertFalse(test.amount.isEmpty)
            XCTAssertFalse(test.purpose.isEmpty)
            XCTAssertEqual(URL(string: test.source)?.scheme, "https")
            XCTAssertTrue(["www.idexx.com", "cvm.msu.edu", "vdl.msu.edu"].contains(URL(string: test.source)?.host ?? ""))
        }
    }

    func testRoutinePanelFamiliesRemainSearchableWithDistinctCBCOptions() throws {
        let families = [
            ("young wellness", "28079999", "2807"),
            ("total health", "10139999", "1013"),
            ("total health plus", "759999", "75"),
            ("senior profile", "7809999", "780"),
            ("geriatric profile", "21769999", "2176"),
            ("senior screen", "8659999", "865")
        ]
        for (query, routineCode, selectCode) in families {
            let foundCodes = Set(LabworkCatalog.search(query, provider: .idexx).map(\.code))
            XCTAssertTrue(foundCodes.contains(routineCode), query)
            XCTAssertTrue(foundCodes.contains(selectCode), query)
            let routine = try XCTUnwrap(LabworkCatalog.tests.first { $0.code == routineCode && $0.provider == "IDEXX" })
            let select = try XCTUnwrap(LabworkCatalog.tests.first { $0.code == selectCode && $0.provider == "IDEXX" })
            XCTAssertTrue(routine.components.contains("IDEXX CBC"), routineCode)
            XCTAssertFalse(routine.components.contains("CBC-Select"), routineCode)
            XCTAssertTrue(select.components.contains("IDEXX CBC-Select"), selectCode)
            XCTAssertTrue(routine.components.contains("SDMA"), routineCode)
            XCTAssertTrue(select.components.contains("SDMA"), selectCode)
        }
    }

    func testProfileUrineRequirementsFollowIncludedUrinalysis() throws {
        // Fixed requirements checked against the current IDEXX directory;
        // not every chemistry/CBC/thyroid profile includes urinalysis.
        let withoutUrine = ["28079999", "2807", "10139999", "1013", "759999", "75", "2377", "2732"]
        let withUrine = ["7809999", "780", "21769999", "2176", "8659999", "865", "2500", "2743"]
        for code in withoutUrine + withUrine {
            let panel = try XCTUnwrap(LabworkCatalog.tests.first { $0.code == code && $0.provider == "IDEXX" })
            let requiresUrine = withUrine.contains(code)
            XCTAssertTrue(panel.amount.contains("2 mL serum"), code)
            XCTAssertTrue(panel.amount.contains("1 mL EDTA"), code)
            XCTAssertEqual(panel.amount.lowercased().contains("urine"), requiresUrine, code)
            XCTAssertEqual(panel.components.lowercased().contains("urinalysis"), requiresUrine, code)
            if requiresUrine {
                XCTAssertTrue(panel.amount.contains("5 mL urine"), code)
                XCTAssertTrue(panel.components.contains("Cystatin B"), code)
            }
        }
        for code in ["21769999", "2176"] {
            let geriatric = try XCTUnwrap(LabworkCatalog.tests.first { $0.code == code && $0.provider == "IDEXX" })
            XCTAssertTrue(geriatric.components.lowercased().contains("free t4"))
            XCTAssertTrue(geriatric.components.lowercased().contains("total t4"))
        }
    }

    func testSearchIncludesComponentsAndFamiliarSendOutBloodworkTerms() {
        for query in ["full send-out bloodwork", "full send out blood work"] {
            XCTAssertTrue(LabworkCatalog.search(query, provider: .idexx).contains { $0.code == "10139999" }, query)
        }
        let thyroid = Set(LabworkCatalog.search("free t4", provider: .idexx).map(\.code))
        XCTAssertTrue(thyroid.contains("21769999"))
        XCTAssertTrue(thyroid.contains("2176"))
        XCTAssertTrue(LabworkCatalog.search("cystatin b", provider: .idexx).contains { $0.code == "865" })
        XCTAssertTrue(LabworkCatalog.search("full send out blood work", provider: .msu).isEmpty)
    }

    func testCardiopetPreservesSpeciesSpecificPlasmaAndSerumInstructions() throws {
        let dog = try XCTUnwrap(LabworkCatalog.tests.first { $0.id == "IDEXX-2665" })
        XCTAssertEqual(dog.species, "Dog")
        XCTAssertEqual(dog.specimen, "EDTA plasma")
        XCTAssertEqual(dog.amount, "1 mL separated EDTA plasma")
        XCTAssertEqual(dog.preparation, "idexxCardiopetDog")
        let dogPreparation = LabworkCatalog.preparation(dog.preparation)
        XCTAssertTrue(dogPreparation.contains("Do not clot"))
        XCTAssertTrue(dogPreparation.lowercased().contains("do not submit whole blood"))
        XCTAssertFalse(dogPreparation.contains("20–30"))

        let cat = try XCTUnwrap(LabworkCatalog.tests.first { $0.id == "IDEXX-2666" })
        XCTAssertEqual(cat.species, "Cat")
        XCTAssertEqual(cat.specimen, "Serum OR EDTA plasma")
        XCTAssertEqual(cat.amount, "1 mL separated serum OR 1 mL separated EDTA plasma")
        XCTAssertEqual(cat.preparation, "idexxCardiopetCat")
        let catPreparation = LabworkCatalog.preparation(cat.preparation)
        XCTAssertTrue(catPreparation.contains("20–30"))
        XCTAssertTrue(catPreparation.lowercased().contains("no clotting"))
        XCTAssertTrue(catPreparation.lowercased().contains("not whole blood"))

        // CBC still requires intact whole blood, unlike these plasma submissions.
        let cbc = try XCTUnwrap(LabworkCatalog.tests.first { $0.id == "IDEXX-375" })
        XCTAssertEqual(cbc.specimen, "EDTA whole blood")
        XCTAssertEqual(cbc.preparation, "idexxBlood")
        XCTAssertTrue(cbc.handling.contains("do not freeze or spin"))
    }
}
