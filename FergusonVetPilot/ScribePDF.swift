import UIKit

enum ScribePDF {
    enum Output { case note, summary, email }
    static func data(encounter: ScribeEncounter, patientID: UUID, translated: Bool, output: Output = .note) throws -> Data {
        guard let patient = encounter.patients.first(where: { $0.id == patientID }),
              let note = encounter.notes.first(where: { $0.patientID == patientID }) else { throw ScribeError.invalid("Patient note not found.") }
        if translated {
            guard note.finalizedAt != nil, let translation = note.translation, translation.sourceText == note.plainText, translation.reviewed else {
                throw ScribeError.invalid("Review the current translation before exporting it.")
            }
        }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        return renderer.pdfData { context in
            var y: CGFloat = 50; var page = 0
            func newPage() {
                context.beginPage(); page += 1; y = 50
                ("VetPilot | \(patient.name) | Page \(page)" as NSString).draw(at: CGPoint(x: 42, y: 762), withAttributes: [.font: UIFont.systemFont(ofSize: 9)])
            }
            func text(_ value: String, size: CGFloat = 11, bold: Bool = false) {
                let style = NSMutableParagraphStyle(); style.baseWritingDirection = .natural
                let storage = NSTextStorage(string: value, attributes: [.font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size), .paragraphStyle: style])
                let manager = NSLayoutManager(); let container = NSTextContainer(size: CGSize(width: 528, height: CGFloat.greatestFiniteMagnitude))
                container.lineFragmentPadding = 0; manager.addTextContainer(container); storage.addLayoutManager(manager); manager.ensureLayout(for: container)
                var glyph = 0
                while glyph < manager.numberOfGlyphs {
                    var range = NSRange(); let rect = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &range)
                    if y + rect.height > 738 { newPage() }
                    manager.drawGlyphs(forGlyphRange: range, at: CGPoint(x: 42, y: y - rect.minY))
                    y += rect.height; glyph = NSMaxRange(range)
                }
                y += 9
            }
            newPage(); text("VetPilot — Patient note", size: 20, bold: true)
            text("Patient: \(patient.name) | \(patient.species)", size: 14, bold: true)
            if !patient.reference.isEmpty { text("Patient reference: \(patient.reference)") }
            text("Visit: \(encounter.sessionDate.formatted(date: .abbreviated, time: .shortened))")
            text(note.finalizedAt == nil ? "DRAFT — NOT REVIEWED" : "Reviewed by \(note.reviewer) on \(note.finalizedAt!.formatted(date: .abbreviated, time: .shortened))", bold: true)
            text("Clinician review is user-entered; this document is not a digital signature or independent clinical certification.")
            if translated, let translation = note.translation {
                text("Reviewed translation: \(translation.language)", bold: true); text(translation.text)
                text("Original source note", size: 14, bold: true); text(note.plainText)
            } else {
                switch output {
                case .note: text(note.plainText)
                case .summary: text("Patient summary — review before sharing", bold: true); text(note.summaryText ?? note.plainText)
                case .email: text("Email draft — review before sending", bold: true); text(note.emailText ?? "Visit summary for \(patient.name)\n\n\(note.plainText)")
                }
            }
            text("Blank sections mean not documented, not normal findings.")
            if !encounter.unassigned.isEmpty { text("This encounter still contains unassigned statements requiring review.", bold: true) }
        }
    }
    static func export(encounter: ScribeEncounter, patientID: UUID, translated: Bool = false, output: Output = .note) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("VetPilotNote-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(translated ? "VetPilot-Patient-Translation.pdf" : "VetPilot-Patient-Note.pdf")
        try data(encounter: encounter, patientID: patientID, translated: translated, output: output).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}
