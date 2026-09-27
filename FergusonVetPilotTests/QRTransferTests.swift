import XCTest
import UIKit
import CoreImage
@testable import FergusonVetPilot
final class QRTransferTests: XCTestCase {
    let token = String(repeating: "a", count: 43)
    func testSharingLinkRestrictsDomainAndCollection() throws {
        let link = "https://vetpilotapp.org/transfer#v1:clinic:\(token)"
        XCTAssertEqual(try QRSharingLink.parse(link, expected: .clinic).token, token)
        XCTAssertThrowsError(try QRSharingLink.parse(link, expected: .cytology))
        for invalid in ["https://evil.example/transfer#v1:clinic:\(token)", "http://vetpilotapp.org/transfer#v1:clinic:\(token)", "https://vetpilotapp.org/transfer?token=secret#v1:clinic:\(token)", "https://person@vetpilotapp.org/transfer#v1:clinic:\(token)", "https://vetpilotapp.org/transfer#v1:dose:\(token)", "https://vetpilotapp.org/transfer#v1:clinic:short"] { XCTAssertThrowsError(try QRSharingLink.parse(invalid)) }
    }
    func testGeneratedQRDecodesToExactLink() throws {
        for collection in [QRCollection.clinic, .cytology] {
            let link = "https://vetpilotapp.org/transfer#v1:\(collection.rawValue):\(token)"
            let image = try QRSharingLink.image(link)
            let ci = try XCTUnwrap(CIImage(image: image))
            let detector = try XCTUnwrap(CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(), options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
            let result = detector.features(in: ci).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
            XCTAssertEqual(result, [link])
        }
    }
    func testPhotoPackageRoundTripPreservesSelectedContent() throws {
        var item = ClinicProtocol(); item.title = "QR test"; item.notes = "Selected notes"; item.category = "Ear cytology"
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 8, height: 8)) }
        item.photos = [ClinicPhoto(caption: "Test image", jpeg: try XCTUnwrap(image.jpegData(compressionQuality: 0.8)))]
        let package = ClinicPackage(items: [item]); let decoded = try ClinicPackage.decode(package.encoded())
        try ClinicTransfer.validatePhotos(decoded.items)
        XCTAssertEqual(decoded.items[0].photos[0].jpeg, item.photos[0].jpeg)
        XCTAssertEqual(decoded.items[0].notes, "Selected notes")
        XCTAssertNotEqual(decoded.items[0].importedCopy().id, item.id)
    }
}
