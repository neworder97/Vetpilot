import XCTest
@testable import FergusonVetPilot
final class CustomMedicationSyncTests: XCTestCase {
    private func item() -> CustomMedicationDefinition {
        CustomMedicationDefinition(generic: "Synthetic", brand: "", drugClass: "", speciesRaw: "Dog", formRaw: "Tablet", indication: "Test", doseBasisRaw: "mg/kg", minDose: 2, maxDose: 3, frequency: "q12h", route: "PO", concentration: nil, sourceReference: "Test only", notes: "")
    }
    func testCrossPlatformSchemaAndMerge() throws {
        let original = item()
        let data = try JSONEncoder().encode(original)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["speciesRaw"] as? String, "Dog")
        XCTAssertEqual(json["doseBasisRaw"] as? String, "mg/kg")
        XCTAssertEqual(try JSONDecoder().decode(CustomMedicationDefinition.self, from: data), original)
        var web = original; web.notes = "Web edit"
        var app = original; app.notes = "App edit"
        XCTAssertEqual(CustomMedicationMerge.merge(local: [original], base: [original], remote: [web]), [web])
        XCTAssertEqual(CustomMedicationMerge.merge(local: [], base: [original], remote: [original]), [])
        let conflicts = CustomMedicationMerge.merge(local: [app], base: [original], remote: [web])
        XCTAssertEqual(conflicts.count, 2)
        XCTAssertEqual(Set(conflicts.map(\.id)).count, 2)
        XCTAssertTrue(conflicts.contains { $0.notes == "App edit" && $0.generic.hasSuffix("(conflict copy)") })
    }
    @MainActor func testAccountIsolationAndGuestPreservation() {
        let store = CustomMedicationStore()
        let guest = store.definitions
        let first = UUID(), second = UUID()
        store.switchAccount(first)
        XCTAssertTrue(store.definitions.isEmpty)
        let med = item(); store.add(med)
        store.switchAccount(second)
        XCTAssertTrue(store.definitions.isEmpty)
        store.switchAccount(first)
        XCTAssertEqual(store.definitions, [med])
        store.switchAccount(nil)
        XCTAssertEqual(store.definitions, guest)
        for id in [first, second] {
            UserDefaults.standard.removeObject(forKey: "ferguson.vetpilot.custom-medications.account." + id.uuidString.lowercased())
        }
    }
}
