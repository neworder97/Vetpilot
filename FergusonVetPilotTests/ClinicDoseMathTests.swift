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
    func testPrescribedVolumeArithmetic() throws {
        let c = try XCTUnwrap(ClinicDoseMath.buprenorphine(weight: 5, pounds: false, dose: 0.012, perKg: true))
        XCTAssertEqual(c.mg, 0.06, accuracy: 1e-10)
        XCTAssertEqual(c.ml, 0.1, accuracy: 1e-10)
        XCTAssertNil(ClinicDoseMath.buprenorphine(weight: 5, pounds: false, dose: -.infinity, perKg: true))
    }
}
