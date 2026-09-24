import UIKit
import UniformTypeIdentifiers
import ImageIO

extension UTType {
    static let vetPilotProtocol = UTType(exportedAs: "com.ferguson.vetpilot.protocol", conformingTo: .json)
}

struct ClinicShare: Identifiable {
    let id = UUID()
    let urls: [URL]
}

enum ClinicTransfer {
    static func validatePhotos(_ items: [ClinicProtocol]) throws {
        for photo in items.flatMap(\.photos) {
            guard let source = CGImageSourceCreateWithData(photo.jpeg as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width <= 4096, height <= 4096 else {
                throw ClinicFileError.invalid("A photo is invalid or exceeds 4096 pixels. No items were imported.")
            }
        }
    }

    static func preparePhoto(_ data: Data) throws -> Data {
        guard data.count <= 30_000_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1600, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary),
              let jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.75), jpeg.count <= 2_000_000 else {
            throw ClinicFileError.invalid("This photo could not be added. Choose a smaller image.")
        }
        return jpeg
    }

    static func export(_ items: [ClinicProtocol], pdf: Bool) throws -> URL {
        let package = ClinicPackage(items: items)
        let data = try package.encoded()
        try validatePhotos(items)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("VetPilotShare-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(pdf ? "VetPilot-My-Clinic.pdf" : "VetPilot-My-Clinic.vetpilot")
        if pdf { try makePDF(items).write(to: url, options: .atomic) }
        else { try data.write(to: url, options: .atomic) }
        return url
    }

    static func makePDF(_ items: [ClinicProtocol]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        return renderer.pdfData { context in
            var y: CGFloat = 50
            var page = 0
            func newPage() {
                context.beginPage(); page += 1; y = 50
                ("VetPilot | My Clinic | Page \(page)" as NSString).draw(at: CGPoint(x: 42, y: 765), withAttributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.gray])
            }
            // Lay out each line with TextKit so long notes continue across pages without clipping.
            func text(_ value: String, size: CGFloat = 11, bold: Bool = false) {
                let font = bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
                let storage = NSTextStorage(string: value, attributes: [.font: font, .foregroundColor: UIColor.black])
                let manager = NSLayoutManager(); let container = NSTextContainer(size: CGSize(width: 528, height: .greatestFiniteMagnitude))
                container.lineFragmentPadding = 0; manager.addTextContainer(container); storage.addLayoutManager(manager)
                manager.ensureLayout(for: container)
                var glyph = 0
                while glyph < manager.numberOfGlyphs {
                    var range = NSRange()
                    let rect = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &range)
                    if y + rect.height > 738 { newPage() }
                    let origin = CGPoint(x: 42, y: y - rect.minY)
                    manager.drawBackground(forGlyphRange: range, at: origin)
                    manager.drawGlyphs(forGlyphRange: range, at: origin)
                    y += rect.height; glyph = NSMaxRange(range)
                }
                y += 7
            }
            for (index, item) in items.enumerated() {
                if index == 0 || y > 50 { newPage() }
                text(item.title, size: 20, bold: true)
                text("\(item.kind) | \(item.category) | Version \(item.revision)")
                text(ClinicProtocol.reviewNotice, bold: true)
                text("Author: \(item.author.isEmpty ? "Not entered" : item.author) | Reviewer (user-entered): \(item.reviewer.isEmpty ? "Not entered" : item.reviewer)")
                text("Review date (user-entered): \(item.reviewedOn.isEmpty ? "Not entered" : item.reviewedOn) | Updated: \(item.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                if !item.summary.isEmpty { text(item.summary) }
                text("Checklist", size: 14, bold: true)
                if item.steps.isEmpty { text("No steps entered.") }
                for (i, step) in item.steps.enumerated() { text("[  ] \(i + 1). \(step.text)") }
                text("Equipment", size: 14, bold: true)
                if item.equipment.isEmpty { text("No equipment entered.") }
                for equipment in item.equipment {
                    text("[  ] \(equipment.name) | Quantity: \(equipment.quantity) | Size: \(equipment.size) | Location: \(equipment.location)")
                }
                if !item.notes.isEmpty { text("Notes", size: 14, bold: true); text(item.notes) }
                for photo in item.photos {
                    guard let image = UIImage(data: photo.jpeg) else { continue }
                    let height = min(240, 480 * image.size.height / max(1, image.size.width))
                    if y + height > 730 { newPage() }
                    let width = height * image.size.width / max(1, image.size.height)
                    image.draw(in: CGRect(x: 42, y: y, width: width, height: height)); y += height + 8
                    if !photo.caption.isEmpty { text(photo.caption) }
                }
                text("Sharing creates a copy, not live synchronization. This PDF is for reading; use the .vetpilot file to import an editable copy.", size: 9)
            }
        }
    }
}
