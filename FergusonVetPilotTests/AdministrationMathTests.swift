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
    func testEverySolidStrengthRoundingAndCourseQuantity() throws {
        var cases = 0
        // Fractional, half-boundary, zero-down and exact-whole inputs across every
        // catalog strength. Expected values are independent of production rounding.
        for medication in MedicationFormulations.organized where [.tablet, .capsule].contains(medication.form) {
            for strength in medication.strengths {
                for (raw, down, nearest, up) in [(0.2,0.0,0.0,1.0),(0.5,0.0,1.0,1.0),(1.24,1.0,1.0,2.0),(1.5,1.0,2.0,2.0),(1.76,1.0,2.0,2.0),(2.0,2.0,2.0,2.0)] {
                    for (mode, expected) in [(SolidDoseRounding.down,down),(.nearest,nearest),(.up,up)] {
                        let plan = try XCTUnwrap(AdministrationMath.solidPlan(targetMg: raw * strength, strengthMg: strength, rounding: mode))
                        XCTAssertEqual(plan.rawUnits,raw,accuracy:1e-10,medication.displayName)
                        XCTAssertEqual(plan.roundedUnits,expected,medication.displayName)
                        XCTAssertEqual(plan.deliveredMg,expected * strength,accuracy:1e-10)
                        for perDay in [1.0,2.0,3.0,4.0] {
                            let count = AdministrationMath.administrations(days:14,dosesPerDay:perDay)
                            XCTAssertEqual(plan.roundedUnits * Double(count),expected * 14 * perDay)
                        }
                        cases += 1
                    }
                }
            }
        }
        XCTAssertGreaterThan(cases,1000)
        print("SOLID_ROUNDING_AUDIT: \(cases) strength/rounding cases; four frequencies each")
    }

    func testCarprofenRoundsAfterDailyDoseDivision() throws {
        let medication = try XCTUnwrap(ClinicalData.medications.first { $0.generic == "Carprofen" })
        let total = try XCTUnwrap(AdministrationMath.selection(for:medication,kg:10,level:.low))
        XCTAssertEqual(total.selected,44,accuracy:1e-12)
        for perDay in [1.0,2.0,3.0,4.0] {
            let perDose = try XCTUnwrap(MedicationSafety.perAdministration(total,frequency:medication.frequency,dosesPerDay:perDay))
            XCTAssertEqual(perDose.selected,44 / perDay,accuracy:1e-12)
            for strength in medication.strengths {
                for mode in SolidDoseRounding.allCases {
                    let plan = try XCTUnwrap(AdministrationMath.solidPlan(targetMg:perDose.selected,strengthMg:strength,rounding:mode))
                    let raw = 44 / perDay / strength
                    let expected = mode == .down ? floor(raw) : mode == .up ? ceil(raw) : raw.rounded()
                    XCTAssertEqual(plan.roundedUnits,expected)
                    XCTAssertEqual(plan.deliveredMg,expected * strength)
                    // A mathematical rounding result must not silently be approved
                    // when it no longer matches this fixed source-backed target.
                    XCTAssertEqual(MedicationSafety.withinRange(plan.deliveredMg,perDose),abs(plan.deliveredMg-perDose.selected)<1e-10)
                }
            }
        }
    }

    func testHalfUnitTiesAbsorbOnlyBinaryNoise() throws {
        for value in [1.5,1.5.nextDown,1.5.nextUp] {
            XCTAssertEqual(try XCTUnwrap(AdministrationMath.solidPlan(targetMg:value,strengthMg:1,rounding:.nearest)).roundedUnits,2)
            XCTAssertEqual(try XCTUnwrap(AdministrationMath.solidPlan(targetMg:value,strengthMg:1,rounding:.down)).roundedUnits,1)
            XCTAssertEqual(ClinicDoseMath.roundedUnits(quantity:value,mode:"Nearest whole"),2)
        }
        XCTAssertEqual(try XCTUnwrap(AdministrationMath.solidPlan(targetMg:1.499999999,strengthMg:1,rounding:.nearest)).roundedUnits,1)
        XCTAssertEqual(try XCTUnwrap(AdministrationMath.solidPlan(targetMg:1.500000001,strengthMg:1,rounding:.nearest)).roundedUnits,2)
    }

}
