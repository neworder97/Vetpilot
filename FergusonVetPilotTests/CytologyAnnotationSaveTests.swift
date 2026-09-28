import XCTest
import UIKit
import ImageIO
@testable import FergusonVetPilot

@MainActor
final class CytologyAnnotationSaveTests: XCTestCase {
    private func image(_ width: Int, _ height: Int, scale: CGFloat = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = scale; format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: CGFloat(width) / scale, height: CGFloat(height) / scale), format: format).image { context in
            UIColor.black.setFill(); context.fill(CGRect(x: 0, y: 0, width: CGFloat(width) / scale, height: CGFloat(height) / scale))
        }
    }
    private func marks(_ photo: ClinicPhoto) -> [WorkspaceRecord] {
        return [("arrow", 0.1, 0.2, 0.45, 0.2, ""), ("circle", 0.55, 0.15, 0.8, 0.4, ""), ("label", 0.1, 0.65, 0.1, 0.65, "Pebbles eye")].map { shape,x,y,x2,y2,label in
            WorkspaceRecord(title: photo.caption, kind: "annotation", target: "photo|" + photo.id.uuidString.lowercased(), value: ["shape": .string(shape), "label": .string(label), "x": .number(x), "y": .number(y), "x2": .number(x2), "y2": .number(y2)])
        }
    }
    private func dimensions(_ data: Data) throws -> (Int, Int) {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return (try XCTUnwrap(props[kCGImagePropertyPixelWidth] as? Int), try XCTUnwrap(props[kCGImagePropertyPixelHeight] as? Int))
    }
    private func assertYellowMarks(_ data: Data, file: StaticString = #filePath, line: UInt = #line) throws {
        let cg = try XCTUnwrap(UIImage(data: data)?.cgImage)
        for (name, rect) in [("arrow", CGRect(x: 0.08, y: 0.12, width: 0.4, height: 0.16)), ("circle", CGRect(x: 0.52, y: 0.12, width: 0.32, height: 0.32)), ("label", CGRect(x: 0.08, y: 0.62, width: 0.65, height: 0.15))] {
            let cropRect = CGRect(x: rect.minX * CGFloat(cg.width), y: rect.minY * CGFloat(cg.height), width: rect.width * CGFloat(cg.width), height: rect.height * CGFloat(cg.height))
            let crop = try XCTUnwrap(cg.cropping(to: cropRect))
            var bytes = [UInt8](repeating: 0, count: 128 * 128 * 4)
            bytes.withUnsafeMutableBytes { raw in
                let context = CGContext(data: raw.baseAddress, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 128 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(crop, in: CGRect(x: 0, y: 0, width: 128, height: 128))
            }
            let yellow = stride(from: 0, to: bytes.count, by: 4).filter { p in
                bytes[p] > 100 && bytes[p+1] > 100 && Int(bytes[p+2]) + 50 < Int(min(bytes[p], bytes[p+1]))
            }.count
            XCTAssertGreaterThan(yellow, 5, "Missing baked-in \(name)", file: file, line: line)
        }
    }

    func testSaveReloadAndShareRetainsOriginalAndAllThreeMarks() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let owner = UUID(), workspace = WorkspaceStore(); workspace.switchAccount(owner)
        defer { UserDefaults.standard.removeObject(forKey: "vetpilot." + owner.uuidString.lowercased() + ".workspace.v1") }
        for (width,height,scale) in [(1600,1200,CGFloat(1)), (1200,1600,CGFloat(3)), (4032,3024,CGFloat(1))] {
            let source = image(width,height,scale:scale), originalData = try XCTUnwrap(source.jpegData(compressionQuality: 0.9))
            let photo = ClinicPhoto(caption: "Original eye", jpeg: originalData), annotations = marks(photo)
            annotations.forEach { XCTAssertTrue(workspace.save($0)) }
            let recordsBefore = workspace.records
            var item = ClinicProtocol(); item.title = "Annotation regression"; item.photos = [photo]
            let file = folder.appendingPathComponent("\(width)-\(height).json"), store = ClinicStore(fileURL: file, collection: "cytology")
            try store.save(item); let baseline = try XCTUnwrap(store.items.first)
            try CytologyAnnotatedCopy.save(photo: photo, in: baseline, image: source, marks: annotations, store: store)
            let reloaded = ClinicStore(fileURL: file, collection: "cytology")
            XCTAssertNil(reloaded.errorMessage)
            let saved = try XCTUnwrap(reloaded.items.first)
            XCTAssertEqual(saved.photos.count,2); XCTAssertEqual(saved.photos[0],photo)
            XCTAssertNotEqual(saved.photos[1].id,photo.id)
            XCTAssertEqual(saved.photos[1].caption,"Original eye — annotated copy")
            XCTAssertLessThanOrEqual(saved.photos[1].jpeg.count,2_000_000)
            let (w,h) = try dimensions(saved.photos[1].jpeg)
            XCTAssertEqual(w,width); XCTAssertEqual(h,height)
            try assertYellowMarks(saved.photos[1].jpeg)
            try ClinicTransfer.validatePhotos([saved])
            let exported = try ClinicTransfer.export([saved],pdf:false)
            defer { try? FileManager.default.removeItem(at: exported.deletingLastPathComponent()) }
            let imported = try ClinicPackage.decode(Data(contentsOf: exported))
            XCTAssertEqual(imported.items[0].photos,saved.photos)
            XCTAssertEqual(workspace.records,recordsBefore)
            let restoredMarks = WorkspaceStore(); restoredMarks.switchAccount(owner)
            XCTAssertEqual(restoredMarks.records,recordsBefore)
        }
    }
    func testOversizedPixelCanvasIsBoundedBeforeJPEGCompression() throws {
        let photo = ClinicPhoto(caption: "Large",jpeg:Data())
        let data = try CytologyAnnotatedCopy.jpeg(image:image(8192,2048),marks:marks(photo))
        let (w,h) = try dimensions(data)
        XCTAssertEqual(w,4096); XCTAssertEqual(h,1024)
        XCTAssertLessThanOrEqual(data.count,2_000_000)
        try assertYellowMarks(data)
    }
    func testRemainingEntryByteBudgetAndOriginalsArePreserved() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:folder) }
        let source=image(1600,1200)
        var data=try XCTUnwrap(source.jpegData(compressionQuality:0.9))
        data.append(Data(repeating:0,count:1_990_000-data.count))
        var item=ClinicProtocol();item.title="Nearly full entry"
        item.photos=(0..<4).map{ClinicPhoto(caption:"Original \($0)",jpeg:data)}
        let file=folder.appendingPathComponent("photos.json"),store=ClinicStore(fileURL:file,collection:"cytology")
        try store.save(item);let baseline=try XCTUnwrap(store.items.first)
        try CytologyAnnotatedCopy.save(photo:baseline.photos[0],in:baseline,image:source,marks:marks(baseline.photos[0]),store:store)
        let saved=try XCTUnwrap(ClinicStore(fileURL:file,collection:"cytology").items.first)
        XCTAssertEqual(Array(saved.photos.prefix(4)),baseline.photos)
        XCTAssertLessThanOrEqual(saved.photos.last!.jpeg.count,40_000)
        XCTAssertLessThanOrEqual(saved.photos.reduce(0){$0+$1.jpeg.count},8_000_000)
        try ClinicTransfer.validatePhotos([saved]);try assertYellowMarks(saved.photos.last!.jpeg)
    }
    func testFullEntryRejectsCopyWithoutChangingSavedPhotos() throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:folder)}
        let source=image(1600,1200),data=try XCTUnwrap(source.jpegData(compressionQuality:0.9))
        var item=ClinicProtocol();item.title="Eight photos";item.photos=(0..<8).map{ClinicPhoto(caption:"Original \($0)",jpeg:data)}
        let file=folder.appendingPathComponent("photos.json"),store=ClinicStore(fileURL:file,collection:"cytology")
        try store.save(item);let baseline=try XCTUnwrap(store.items.first),before=try Data(contentsOf:file)
        XCTAssertThrowsError(try CytologyAnnotatedCopy.save(photo:baseline.photos[0],in:baseline,image:source,marks:marks(baseline.photos[0]),store:store))
        XCTAssertEqual(try Data(contentsOf:file),before)
        XCTAssertThrowsError(try CytologyAnnotatedCopy.jpeg(image:source,marks:marks(baseline.photos[0]),maxBytes:0))
        XCTAssertThrowsError(try CytologyAnnotatedCopy.jpeg(image:source,marks:marks(baseline.photos[0]),maxBytes:1))
    }
}
