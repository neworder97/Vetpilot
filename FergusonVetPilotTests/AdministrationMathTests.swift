import XCTest
@testable import FergusonVetPilot

final class AdministrationMathTests: XCTestCase {
    func testLowMiddleHighInterpolation() {
        XCTAssertEqual(AdministrationMath.interpolate(10, 20, level: .low), 10, accuracy: 0.000001)
        XCTAssertEqual(AdministrationMath.interpolate(10, 20, level: .middle), 15, accuracy: 0.000001)
        XCTAssertEqual(AdministrationMath.interpolate(10, 20, level: .high), 20, accuracy: 0.000001)
    }

    func testWholeSolidRoundingShowsDeliveredDose() throws {
        let down = try XCTUnwrap(AdministrationMath.solidPlan(targetMg: 62, strengthMg: 50, rounding: .down))
        XCTAssertEqual(down.rawUnits, 1.24, accuracy: 0.000001)
        XCTAssertEqual(down.roundedUnits, 1, accuracy: 0.000001)
        XCTAssertEqual(down.deliveredMg, 50, accuracy: 0.000001)

        let up = try XCTUnwrap(AdministrationMath.solidPlan(targetMg: 62, strengthMg: 50, rounding: .up))
        XCTAssertEqual(up.roundedUnits, 2, accuracy: 0.000001)
        XCTAssertEqual(up.deliveredMg, 100, accuracy: 0.000001)
    }

    func testMcgPerKgMinuteConvertsAgainstMgPerMl() throws {
        let d = ProtocolMedicationDefinition(
            medicationKey: "test", generic: "Lidocaine", speciesRaw: Species.dog.rawValue,
            doseBasisRaw: ProtocolDoseBasis.mcgKgMin.rawValue, minDose: 25, maxDose: 80,
            frequency: "continuous", route: "IV CRI", strengths: [], concentration: 20,
            sourceReference: "test", notes: "", veterinarianApproved: true
        )
        let middle = try XCTUnwrap(AdministrationMath.selection(for: d, kg: 20, level: .middle))
        XCTAssertEqual(middle.selected, 1050, accuracy: 0.000001) // 52.5 mcg/kg/min × 20 kg
        let volume = try XCTUnwrap(AdministrationMath.volume(selection: middle, basis: .mcgKgMin, concentration: 20))
        XCTAssertEqual(volume.value, 3.15, accuracy: 0.000001)
        XCTAssertEqual(volume.unit, "mL/hr")
    }

    func testBsaUsesAuditedDogAndCatConstants() throws {
        let dog = ProtocolMedicationDefinition(
            medicationKey: "dog", generic: "Chemo", speciesRaw: Species.dog.rawValue,
            doseBasisRaw: ProtocolDoseBasis.mgM2.rawValue, minDose: 30, maxDose: 30,
            frequency: "once", route: "IV", strengths: [], concentration: nil,
            sourceReference: "test", notes: "", veterinarianApproved: true
        )
        let cat = ProtocolMedicationDefinition(
            medicationKey: "cat", generic: "Chemo", speciesRaw: Species.cat.rawValue,
            doseBasisRaw: ProtocolDoseBasis.mgM2.rawValue, minDose: 30, maxDose: 30,
            frequency: "once", route: "IV", strengths: [], concentration: nil,
            sourceReference: "test", notes: "", veterinarianApproved: true
        )
        let dogSelection = try XCTUnwrap(AdministrationMath.selection(for: dog, kg: 10, level: .middle))
        let catSelection = try XCTUnwrap(AdministrationMath.selection(for: cat, kg: 4, level: .middle))
        XCTAssertEqual(dogSelection.selected, 14.07, accuracy: 0.02)
        XCTAssertEqual(catSelection.selected, 7.56, accuracy: 0.02)
    }

    func testDispenseAdministrationCountRoundsPartialScheduleUp() {
        XCTAssertEqual(AdministrationMath.administrations(days: 7, dosesPerDay: 0.5), 4)
        XCTAssertEqual(AdministrationMath.administrations(days: 14, dosesPerDay: 2), 28)
    }
}
