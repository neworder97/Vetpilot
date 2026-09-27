import XCTest
import UIKit
@testable import FergusonVetPilot

final class WebsiteAdditionsTests: XCTestCase {
    func testCompiledLogoMatchesWebsiteStethoscopeArtwork() throws {
        let bundle = Bundle(for: VetPilotAccount.self)
        let sourceURL = try XCTUnwrap(bundle.url(forResource: "VetPilotStethoscope", withExtension: "png"))
        let source = try XCTUnwrap(UIImage(contentsOfFile: sourceURL.path)?.cgImage)
        let compiled = try XCTUnwrap(UIImage(named: "ShepherdIcon", in: bundle, compatibleWith: nil)?.cgImage)
        func pixels(_ image: CGImage) throws -> [UInt8] {
            let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
            let context = try XCTUnwrap(CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 64, height: 64))
            let data = try XCTUnwrap(context.data)
            return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: 64 * 64 * 4))
        }
        XCTAssertEqual(source.width, 1024)
        XCTAssertEqual(source.height, 1024)
        let expected = try pixels(source), actual = try pixels(compiled)
        let difference = zip(expected, actual).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        XCTAssertLessThanOrEqual(difference, expected.count, "Compiled logo must match the website artwork")
    }

    func testReviewRequiresRatingAndFeatureAndExplicitClinicalDetails() {
        var draft = VetPilotReviewDraft()
        XCTAssertNotNil(draft.validationError)
        draft.rating = 5; draft.features = ["My Clinic"]
        XCTAssertNil(draft.validationError)
        XCTAssertFalse(draft.testimonialPermission)
        draft.categories = ["Found a possible error"]
        XCTAssertTrue(draft.clinicalPriority)
        XCTAssertNotNil(draft.validationError)
        draft.correctionFeature = "Medications"; draft.correctionItem = "Example"; draft.problem = "Needs review"
        XCTAssertNil(draft.validationError)
    }
    func testReviewUsesSameAccountAndStableSubmissionForRetries() throws {
        var draft = VetPilotReviewDraft(); draft.rating = 4; draft.features = ["Cytology"]
        let owner = UUID(), first = draft.record(owner: owner), retry = draft.record(owner: owner)
        XCTAssertEqual(first["id"] as? String, retry["id"] as? String)
        XCTAssertEqual(first["user_id"] as? String, owner.uuidString.lowercased())
        let payload = try XCTUnwrap(first["payload"] as? [String: Any])
        XCTAssertEqual(payload["owner"] as? String, owner.uuidString.lowercased())
        XCTAssertEqual(payload["testimonialPermission"] as? Bool, false)
        XCTAssertEqual(first["clinical_priority"] as? Bool, false)
        XCTAssertNoThrow(try JSONSerialization.data(withJSONObject: first))
    }
    func testReviewProfessionalAndLengthValidation() {
        var draft = VetPilotReviewDraft(); draft.rating = 3; draft.features = ["Nutrition"]; draft.licensedVet = true
        XCTAssertNotNil(draft.validationError)
        draft.reviewAreas = ["Nutrition calculations"]
        XCTAssertNil(draft.validationError)
        draft.comments = String(repeating: "x", count: 5001)
        XCTAssertNotNil(draft.validationError)
    }
    func testSourceDirectoryIncludedAndReadable() throws {
        let url = try XCTUnwrap(Bundle(for: VetPilotAccount.self).url(forResource: "WebsiteSourceDirectory", withExtension: "json"))
        let entries = try JSONDecoder().decode([VetPilotSourceEntry].self, from: Data(contentsOf: url))
        XCTAssertGreaterThan(entries.count, 100)
        XCTAssertTrue(entries.contains { $0.title.contains("Carprofen") })
    }
}
