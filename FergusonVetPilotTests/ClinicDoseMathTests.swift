import XCTest
@testable import FergusonVetPilot
final class ClinicDoseMathTests: XCTestCase {
    func testClinicGabapentinChoices() throws {
        for dose in [15.0,25,30,50] {
            let c = try XCTUnwrap(ClinicDoseMath.gabapentin(weight: 10, pounds: false, dose: dose, strength: 100))
            XCTAssertEqual(c.mg, 10 * dose)
            XCTAssertEqual(try XCTUnwrap(c.quantity), dose / 10)
            let lb = try XCTUnwrap(ClinicDoseMath.gabapentin(weight: 10 / 0.45359237, pounds: true, dose: dose, strength: 100))
            XCTAssertEqual(lb.mg, c.mg, accuracy: 1e-8)
        }
        XCTAssertNil(ClinicDoseMath.gabapentin(weight: 10, pounds: false, dose: 27.5, strength: 100))
        XCTAssertNil(ClinicDoseMath.gabapentin(weight: 0, pounds: false, dose: 15, strength: 100))
        XCTAssertNil(ClinicDoseMath.gabapentin(weight: 10, pounds: false, dose: 15, strength: 0))
    }
    func testCourseQuantityUsesSelectedFrequencyAndDuration() throws {
        for hours in [6,8,12,24] {
            let c = try XCTUnwrap(ClinicDoseMath.course(quantity: 2, hours: hours, days: 7))
            XCTAssertEqual(c.administrations, 7 * 24 / hours)
            XCTAssertEqual(c.units, Double(c.administrations * 2))
        }
        XCTAssertNil(ClinicDoseMath.course(quantity: 2, hours: 0, days: 7))
        XCTAssertNil(ClinicDoseMath.course(quantity: 2, hours: 8, days: 0))
        XCTAssertNil(ClinicDoseMath.course(quantity: .infinity, hours: 8, days: 7))
    }
    func testPrescribedVolumeArithmetic() throws {
        let c = try XCTUnwrap(ClinicDoseMath.buprenorphine(weight: 5, pounds: false, dose: 0.012, perKg: true))
        XCTAssertEqual(c.mg, 0.06, accuracy: 1e-10)
        XCTAssertEqual(c.ml, 0.1, accuracy: 1e-10)
        XCTAssertNil(ClinicDoseMath.buprenorphine(weight: 5, pounds: false, dose: -.infinity, perKg: true))
    }
    func testAdministrationSummaryKeepsPerDoseAndCourseUnits() throws {
        for unit in ["tablet", "capsule", "mL"] {
            let text = try XCTUnwrap(PrescriptionSummary.text(amount: 1, unit: unit, route: "PO", hours: 12, days: 15))
            XCTAssertTrue(text.contains("Give 1 \(unit) PO q12 hours for 15 days"))
            XCTAssertTrue(text.contains("Quantity: 30 \(unit)"))
            XCTAssertTrue(try XCTUnwrap(PrescriptionSummary.text(amount: 1, unit: unit, route: "PO", hours: 12, days: 30)).contains("Quantity: 60"))
        }
        XCTAssertTrue(try XCTUnwrap(PrescriptionSummary.text(amount: 0.25, unit: "mL", route: "PO", hours: 8, days: 7)).contains("Quantity: 5.25 mL"))
        let fraction = try XCTUnwrap(PrescriptionSummary.text(amount: 0.5, unit: "capsule", route: "PO", hours: 12, days: 15))
        XCTAssertFalse(fraction.hasPrefix("Give"))
        XCTAssertTrue(fraction.contains("Calculated quantity: 15 capsule equivalents"))
        XCTAssertNil(PrescriptionSummary.text(amount: 1, unit: "mL", route: "PO", hours: 0, days: 15))
        XCTAssertNil(PrescriptionSummary.text(amount: .infinity, unit: "mL", route: "PO", hours: 12, days: 15))
    }

}
