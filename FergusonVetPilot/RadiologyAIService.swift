import Foundation
import UIKit
import CoreGraphics

struct RadiologyAIFinding: Codable, Identifiable {
    var id: String { observation + explanation }
    let observation: String
    let confidence: String
    let explanation: String
}

struct RadiologyAIDifferential: Codable, Identifiable {
    var id: String { name + whyItFits }
    let name: String
    let confidence: String
    let whyItFits: String
    let whatArguesAgainst: String
}

struct RadiologyAIReference: Codable, Identifiable {
    var id: String { url + title }
    let title: String
    let url: String
    let sourceType: String
    let relevance: String
}

struct RadiologyAIResult: Codable {
    let isRadiograph: Bool
    let radiographConfidence: String
    let radiographAssessment: String
    let studyAssessment: String
    let imageQuality: String
    let findings: [RadiologyAIFinding]
    let differentials: [RadiologyAIDifferential]
    let urgentFlags: [String]
    let crossReferenceSummary: String
    let references: [RadiologyAIReference]
    let searchTerms: [String]
    let limitations: [String]
}

struct RadiologyImageFeatures: Equatable {
    let meanLuminance: Double
    let contrast: Double
    let dynamicRange: Double
    let darkFraction: Double
    let brightFraction: Double
    let leftMean: Double
    let rightMean: Double
    let topMean: Double
    let bottomMean: Double
    let centerMean: Double
    let peripheralMean: Double
    let leftRightDifference: Double
    let topBottomDifference: Double
    let centerPeripheralDifference: Double
    let edgeDensity: Double
    let localHeterogeneity: Double

    var qualitySummary: String {
        var parts: [String] = []
        if contrast < 0.07 { parts.append("low global contrast") }
        if dynamicRange < 0.35 { parts.append("limited tonal range") }
        if darkFraction > 0.45 { parts.append("large dark/clipped area") }
        if brightFraction > 0.30 { parts.append("large bright/clipped area") }
        if edgeDensity < 0.025 { parts.append("low structural sharpness") }
        if parts.isEmpty { return "Usable global contrast and tonal range for automated pattern measurements." }
        return "Technical limitations detected: " + parts.joined(separator: ", ") + "."
    }
}

enum RadiologyAIError: LocalizedError {
    case imageEncoding

    var errorDescription: String? {
        switch self {
        case .imageEncoding:
            return "The image could not be measured. Try importing the radiograph again."
        }
    }
}

final class RadiologyAIService {
    static let shared = RadiologyAIService()
    private init() {}

    func analyze(
        image: UIImage,
        species: Species,
        studyRegion: String,
        clinicalHistory: String,
        priorConfirmedCases: String,
        inspection: RadiographInspection
    ) async throws -> RadiologyAIResult {
        guard let features = Self.extractFeatures(from: image) else {
            throw RadiologyAIError.imageEncoding
        }

        let local = Self.localInterpretation(
            features: features,
            species: species,
            region: studyRegion,
            clinicalHistory: clinicalHistory,
            priorConfirmedCases: priorConfirmedCases,
            inspection: inspection
        )

        let webEvidence = await RadiologyEvidenceService.shared.lookup(
            species: species,
            region: studyRegion,
            terms: local.searchTerms
        )

        return RadiologyAIResult(
            isRadiograph: inspection.canAnalyze,
            radiographConfidence: Self.confidenceLabel(inspection.score),
            radiographAssessment: inspection.explanation,
            studyAssessment: local.studyAssessment,
            imageQuality: features.qualitySummary,
            findings: local.findings,
            differentials: local.differentials,
            urgentFlags: local.urgentFlags,
            crossReferenceSummary: webEvidence.summary,
            references: webEvidence.references,
            searchTerms: local.searchTerms,
            limitations: local.limitations
        )
    }

    static func extractFeatures(from image: UIImage) -> RadiologyImageFeatures? {
        let width = 128
        let height = 128

        // Render through UIImage.draw so EXIF / UIImage orientation is applied before
        // measurements are taken. Aspect-fit into a black canvas; the collimation
        // detector below removes uniform outer padding when possible.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let canvasSize = CGSize(width: width, height: height)
        let normalized = UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: canvasSize))

            let sourceSize = image.size
            guard sourceSize.width > 0, sourceSize.height > 0 else { return }
            let scale = min(canvasSize.width / sourceSize.width, canvasSize.height / sourceSize.height)
            let drawSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            let drawRect = CGRect(
                x: (canvasSize.width - drawSize.width) / 2,
                y: (canvasSize.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            image.draw(in: drawRect)
        }

        guard let cgImage = normalized.cgImage else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let values = pixels.map { Double($0) / 255.0 }

        // Estimate a uniform outer background/collimation field from the image edge.
        // We crop only when the edge is truly uniform and the detected active field
        // remains large enough; otherwise the full image is retained.
        let border = 5
        var borderValues: [Double] = []
        borderValues.reserveCapacity((width + height) * border * 2)
        for y in 0..<height {
            for x in 0..<width where x < border || x >= width - border || y < border || y >= height - border {
                borderValues.append(values[y * width + x])
            }
        }

        let sortedBorder = borderValues.sorted()
        let borderMedian = sortedBorder.isEmpty ? 0 : sortedBorder[sortedBorder.count / 2]
        let borderMean = borderValues.isEmpty ? 0 : borderValues.reduce(0, +) / Double(borderValues.count)
        let borderVariance = borderValues.isEmpty ? 1 : borderValues.reduce(0) { $0 + pow($1 - borderMean, 2) } / Double(borderValues.count)
        let borderStdDev = sqrt(borderVariance)
        let activityThreshold = max(0.05, borderStdDev * 2.5)

        func columnActivity(_ x: Int) -> Double {
            var active = 0
            for y in 0..<height where abs(values[y * width + x] - borderMedian) > activityThreshold {
                active += 1
            }
            return Double(active) / Double(height)
        }

        func rowActivity(_ y: Int) -> Double {
            var active = 0
            let row = y * width
            for x in 0..<width where abs(values[row + x] - borderMedian) > activityThreshold {
                active += 1
            }
            return Double(active) / Double(width)
        }

        var x0 = 0
        var x1 = width
        var y0 = 0
        var y1 = height
        if borderStdDev < 0.08 {
            let activeColumns = (0..<width).filter { columnActivity($0) >= 0.08 }
            let activeRows = (0..<height).filter { rowActivity($0) >= 0.08 }
            if let minX = activeColumns.first,
               let maxX = activeColumns.last,
               let minY = activeRows.first,
               let maxY = activeRows.last {
                let candidateWidth = maxX - minX + 1
                let candidateHeight = maxY - minY + 1
                if candidateWidth >= width * 2 / 5, candidateHeight >= height * 2 / 5 {
                    x0 = max(0, minX - 2)
                    x1 = min(width, maxX + 3)
                    y0 = max(0, minY - 2)
                    y1 = min(height, maxY + 3)
                }
            }
        }

        var analysisValues: [Double] = []
        analysisValues.reserveCapacity((x1 - x0) * (y1 - y0))
        for y in y0..<y1 {
            let row = y * width
            for x in x0..<x1 {
                analysisValues.append(values[row + x])
            }
        }
        guard !analysisValues.isEmpty else { return nil }

        let count = Double(analysisValues.count)
        let mean = analysisValues.reduce(0, +) / count
        let variance = analysisValues.reduce(0) { $0 + pow($1 - mean, 2) } / count
        let contrast = sqrt(variance)

        let sorted = analysisValues.sorted()
        let lowIndex = Int(Double(sorted.count - 1) * 0.05)
        let highIndex = Int(Double(sorted.count - 1) * 0.95)
        let dynamicRange = max(0, sorted[highIndex] - sorted[lowIndex])
        let darkFraction = Double(analysisValues.filter { $0 < 0.08 }.count) / count
        let brightFraction = Double(analysisValues.filter { $0 > 0.92 }.count) / count

        func meanRegion(xStart: Int, xEnd: Int, yStart: Int, yEnd: Int) -> Double {
            let xs = max(x0, min(x1, xStart))
            let xe = max(xs, min(x1, xEnd))
            let ys = max(y0, min(y1, yStart))
            let ye = max(ys, min(y1, yEnd))
            var total = 0.0
            var n = 0
            for y in ys..<ye {
                let row = y * width
                for x in xs..<xe {
                    total += values[row + x]
                    n += 1
                }
            }
            return n > 0 ? total / Double(n) : mean
        }

        let cropWidth = x1 - x0
        let cropHeight = y1 - y0
        let midX = x0 + cropWidth / 2
        let midY = y0 + cropHeight / 2
        let left = meanRegion(xStart: x0, xEnd: midX, yStart: y0, yEnd: y1)
        let right = meanRegion(xStart: midX, xEnd: x1, yStart: y0, yEnd: y1)
        let top = meanRegion(xStart: x0, xEnd: x1, yStart: y0, yEnd: midY)
        let bottom = meanRegion(xStart: x0, xEnd: x1, yStart: midY, yEnd: y1)

        let centerX0 = x0 + cropWidth / 4
        let centerX1 = x0 + cropWidth * 3 / 4
        let centerY0 = y0 + cropHeight / 4
        let centerY1 = y0 + cropHeight * 3 / 4
        let center = meanRegion(xStart: centerX0, xEnd: centerX1, yStart: centerY0, yEnd: centerY1)
        let centerPixelCount = Double(max(1, (centerX1 - centerX0) * (centerY1 - centerY0)))
        let fullTotal = mean * count
        let centerTotal = center * centerPixelCount
        let peripheralPixelCount = max(1, count - centerPixelCount)
        let peripheral = (fullTotal - centerTotal) / peripheralPixelCount

        var edgeTotal = 0.0
        var edgeCount = 0
        if cropWidth > 2, cropHeight > 2 {
            for y in (y0 + 1)..<(y1 - 1) {
                for x in (x0 + 1)..<(x1 - 1) {
                    let i = y * width + x
                    let gx = values[i + 1] - values[i - 1]
                    let gy = values[i + width] - values[i - width]
                    edgeTotal += min(1, sqrt(gx * gx + gy * gy))
                    edgeCount += 1
                }
            }
        }
        let edgeDensity = edgeCount > 0 ? edgeTotal / Double(edgeCount) : 0

        var blockMeans: [Double] = []
        let blocks = 4
        for by in 0..<blocks {
            for bx in 0..<blocks {
                let bx0 = x0 + cropWidth * bx / blocks
                let bx1 = x0 + cropWidth * (bx + 1) / blocks
                let by0 = y0 + cropHeight * by / blocks
                let by1 = y0 + cropHeight * (by + 1) / blocks
                blockMeans.append(meanRegion(xStart: bx0, xEnd: bx1, yStart: by0, yEnd: by1))
            }
        }
        let blockMean = blockMeans.reduce(0, +) / Double(blockMeans.count)
        let localHeterogeneity = sqrt(
            blockMeans.reduce(0) { $0 + pow($1 - blockMean, 2) } / Double(blockMeans.count)
        )

        return RadiologyImageFeatures(
            meanLuminance: mean,
            contrast: contrast,
            dynamicRange: dynamicRange,
            darkFraction: darkFraction,
            brightFraction: brightFraction,
            leftMean: left,
            rightMean: right,
            topMean: top,
            bottomMean: bottom,
            centerMean: center,
            peripheralMean: peripheral,
            leftRightDifference: abs(left - right),
            topBottomDifference: abs(top - bottom),
            centerPeripheralDifference: abs(center - peripheral),
            edgeDensity: edgeDensity,
            localHeterogeneity: localHeterogeneity
        )
    }

    private struct LocalInterpretation {
        let studyAssessment: String
        let findings: [RadiologyAIFinding]
        let differentials: [RadiologyAIDifferential]
        let urgentFlags: [String]
        let searchTerms: [String]
        let limitations: [String]
    }

    private static func localInterpretation(
        features: RadiologyImageFeatures,
        species: Species,
        region: String,
        clinicalHistory: String,
        priorConfirmedCases: String,
        inspection: RadiographInspection
    ) -> LocalInterpretation {
        let normalizedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let thorax = normalizedRegion.contains("thorax") || normalizedRegion.contains("chest") || normalizedRegion.contains("lung")
        let abdomen = normalizedRegion.contains("abdomen") || normalizedRegion.contains("abdominal") || normalizedRegion.contains("gi")
        let tokens = Set(normalizedRegion.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        let lateralView = normalizedRegion.contains("lateral") || tokens.contains("lat")
        let frontalView = tokens.contains("vd") || tokens.contains("dv") || tokens.contains("ap") || tokens.contains("pa") || normalizedRegion.contains("ventrodorsal") || normalizedRegion.contains("dorsoventral")

        var findings: [RadiologyAIFinding] = []
        var differentials: [RadiologyAIDifferential] = []
        var terms: [String] = []
        var urgentFlags: [String] = []

        if features.leftRightDifference >= 0.10 {
            let observation: String
            let explanation: String
            if frontalView {
                observation = "Left-right image density asymmetry"
                explanation = "On the entered frontal projection, the two image halves differ in average radiographic density by about \(Int(features.leftRightDifference * 100)) percentage points. Rotation/positioning can cause this, while focal disease can also contribute."
            } else if lateralView {
                observation = "Long-axis density asymmetry on lateral view"
                explanation = "The two long-axis image halves differ in average radiographic density by about \(Int(features.leftRightDifference * 100)) percentage points. On a lateral projection this is a regional distribution measurement, not a left-versus-right lung comparison."
            } else {
                observation = "Image-half density asymmetry"
                explanation = "The two image halves differ in average radiographic density by about \(Int(features.leftRightDifference * 100)) percentage points. Because the projection was not specified, VetPilot does not assign this difference to a specific anatomical side."
            }
            findings.append(.init(
                observation: observation,
                confidence: features.leftRightDifference >= 0.16 ? "moderate" : "low",
                explanation: explanation
            ))
            terms += ["radiographic asymmetry", "focal opacity"]
        }

        if features.centerPeripheralDifference >= 0.10 {
            let centerBrighter = features.centerMean > features.peripheralMean
            findings.append(.init(
                observation: centerBrighter ? "Central region is relatively more opaque" : "Central region is relatively more lucent",
                confidence: features.centerPeripheralDifference >= 0.16 ? "moderate" : "low",
                explanation: "The center and peripheral portions of the image differ in mean density by about \(Int(features.centerPeripheralDifference * 100)) percentage points. This is a global pattern measurement, not organ segmentation."
            ))
            terms.append(centerBrighter ? "increased central opacity" : "relative central lucency")
        }

        if features.localHeterogeneity >= 0.10 {
            findings.append(.init(
                observation: "Regional density heterogeneity",
                confidence: features.localHeterogeneity >= 0.15 ? "moderate" : "low",
                explanation: "A coarse 4×4 map shows uneven regional density distribution. This can reflect anatomy, positioning, superimposition, or focal/multifocal disease."
            ))
            terms += ["regional opacity", "multifocal radiographic pattern"]
        }

        if features.edgeDensity < 0.025 {
            findings.append(.init(
                observation: "Reduced structural sharpness",
                confidence: "moderate",
                explanation: "Edge strength is low across the image, which may reflect motion, focus, compression, screenshot scaling, or low-detail acquisition."
            ))
            terms.append("radiograph image quality motion")
        }

        if features.contrast < 0.07 || features.dynamicRange < 0.35 {
            findings.append(.init(
                observation: "Limited contrast / tonal separation",
                confidence: "moderate",
                explanation: "The image has limited global tonal separation, which can reduce sensitivity for subtle abnormalities."
            ))
            terms.append("radiograph exposure image quality")
        }

        if findings.isEmpty {
            findings.append(.init(
                observation: "No large global density asymmetry detected",
                confidence: "moderate",
                explanation: "The analyzer did not measure a strong whole-image asymmetry or major contrast abnormality. This does not exclude focal or subtle disease."
            ))
            terms.append("veterinary radiograph interpretation")
        }

        if thorax {
            let projectionSupportsSideComparison = frontalView
            let regionalThoracicFlag = features.localHeterogeneity >= 0.10 || (projectionSupportsSideComparison && features.leftRightDifference >= 0.10)
            if regionalThoracicFlag {
                differentials.append(.init(
                    name: projectionSupportsSideComparison ? "Asymmetric or focal thoracic opacity pattern" : "Regional thoracic opacity pattern",
                    confidence: "low",
                    whyItFits: projectionSupportsSideComparison
                        ? "The entered frontal projection contains measurable side-to-side or regional density differences. Broad causes can include positioning/rotation, focal pulmonary opacity, atelectasis, pleural change, or a focal lesion."
                        : "The image contains measurable regional density heterogeneity. Without a frontal projection, VetPilot avoids treating image-half density as a left-versus-right lung comparison; broad causes can still include positioning, focal pulmonary opacity, atelectasis, pleural change, or a focal lesion.",
                    whatArguesAgainst: "This analyzer does not segment lungs, heart, vessels, or pleural space and cannot distinguish those causes by itself. Orthogonal views and clinician review are needed."
                ))
                terms += ["canine feline thoracic radiograph focal pulmonary opacity", "atelectasis pneumonia pulmonary edema radiograph veterinary"]
            }

            if features.centerMean > features.peripheralMean + 0.10 {
                differentials.append(.init(
                    name: "Increased central thoracic soft-tissue opacity pattern",
                    confidence: "low",
                    whyItFits: "The central image region is measurably denser than the periphery. Depending on projection and anatomy, broad possibilities include expected mediastinal/cardiac structures, pulmonary opacity, positioning, or exposure effects.",
                    whatArguesAgainst: "No validated organ segmentation or lesion-classification model is installed, so this is a pattern flag rather than a disease classification."
                ))
                terms += ["central pulmonary opacity dog cat radiograph", "cardiopulmonary radiograph veterinary"]
            }
        } else if abdomen {
            if features.localHeterogeneity >= 0.10 || features.centerPeripheralDifference >= 0.10 {
                differentials.append(.init(
                    name: "Uneven abdominal gas/soft-tissue opacity pattern",
                    confidence: "low",
                    whyItFits: "The abdominal image shows measurable regional density variation. Broad causes can include normal organ/gas distribution, positioning, distention, mass effect, fluid, or focal material.",
                    whatArguesAgainst: "The analyzer does not segment individual abdominal organs or bowel loops, so it cannot determine the specific cause from this measurement alone."
                ))
                terms += ["veterinary abdominal radiograph gas pattern", "abdominal radiography dog cat opacity"]
            }
        } else if features.localHeterogeneity >= 0.12 || features.leftRightDifference >= 0.12 {
            differentials.append(.init(
                name: "Regional radiographic density abnormality",
                confidence: "low",
                whyItFits: "The image contains a measurable regional density difference that may represent anatomy, positioning, superimposition, or a focal abnormality.",
                whatArguesAgainst: "The study region was not specific enough for a validated anatomy-specific interpretation."
            ))
            terms += ["veterinary radiograph regional opacity", "diagnostic imaging dog cat radiography"]
        }

        if differentials.isEmpty {
            differentials.append(.init(
                name: "No strong global pattern classification",
                confidence: "low",
                whyItFits: "The automated measurements did not cross the conservative thresholds used for a large global density-pattern flag.",
                whatArguesAgainst: "Subtle, small, or anatomy-specific abnormalities can be present even when global measurements are unremarkable."
            ))
        }

        // Avoid automatically declaring emergencies from whole-image statistics.
        // Urgent flags are reserved for a future validated lesion model or clinician-entered findings.
        urgentFlags = []

        let regionDisplay = region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "unspecified region" : region
        let studyAssessment = "\(species.rawValue) \(regionDisplay): local image analysis found \(findings.count) measurable pattern observation(s). The ranked items below are broad radiographic pattern possibilities, not diagnoses."

        var limitations = [
            "This build measures image-level density, contrast, symmetry, sharpness, and regional heterogeneity; it is not yet a radiologist-validated lesion classifier.",
            "JPEG/PNG screenshots can alter exposure, contrast, orientation, and grayscale values compared with the original DICOM study.",
            "A single view can hide or mimic abnormalities; orthogonal views and clinical context remain important.",
            "Live literature matches provide context only and do not prove that the patient's image has the condition described in an article."
        ]

        if inspection.verdict == .uncertain {
            limitations.insert("The local radiograph precheck was uncertain, so the image should be visually confirmed as an X-ray before relying on any pattern measurements.", at: 0)
        }

        if !priorConfirmedCases.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            limitations.append("Prior clinician-confirmed local cases are retained as review memory but are not used to raise disease confidence without a validated similarity model.")
        }

        if !clinicalHistory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            terms += historyKeywords(clinicalHistory)
        }

        terms = deduplicated(terms).prefix(8).map { $0 }

        return LocalInterpretation(
            studyAssessment: studyAssessment,
            findings: findings,
            differentials: differentials,
            urgentFlags: urgentFlags,
            searchTerms: terms,
            limitations: limitations
        )
    }

    private static func historyKeywords(_ history: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        let stopWords: Set<String> = [
            "with", "from", "that", "this", "have", "been", "were", "into", "their", "they", "them", "patient", "history", "radiograph", "xray", "x-ray", "production", "pipeline", "validation", "test", "testing"
        ]
        let tokens = history.lowercased().components(separatedBy: separators)
            .filter { $0.count >= 4 && !stopWords.contains($0) }
        return Array(tokens.prefix(4))
    }

    private static func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.lowercased()
            guard !trimmed.isEmpty, seen.insert(key).inserted else { continue }
            output.append(trimmed)
        }
        return output
    }

    private static func confidenceLabel(_ score: Double) -> String {
        if score >= 0.80 { return "high" }
        if score >= 0.55 { return "moderate" }
        return "low"
    }

    static func googleImagesURL(
        species: Species,
        region: String,
        searchTerms: [String]
    ) -> URL? {
        let terms = ([species.rawValue, region, "veterinary radiograph x-ray"] + Array(searchTerms.prefix(4)))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")

        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: "tbm", value: "isch"),
            URLQueryItem(name: "q", value: terms)
        ]
        return components?.url
    }

    static func vinSearchURL(
        species: Species,
        region: String,
        searchTerms: [String]
    ) -> URL? {
        let terms = (["site:vin.com", species.rawValue, region, "veterinary radiograph"] + Array(searchTerms.prefix(4)))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")

        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: terms)]
        return components?.url
    }
}

private final class RadiologyEvidenceService {
    static let shared = RadiologyEvidenceService()
    private init() {}

    struct Evidence {
        let summary: String
        let references: [RadiologyAIReference]
    }

    private struct ESearchResponse: Decodable {
        struct Result: Decodable {
            let count: String
            let idlist: [String]
        }
        let esearchresult: Result
    }

    private struct ESummaryResponse: Decodable {
        struct Article: Decodable {
            let uid: String?
            let title: String?
            let pubdate: String?
            let source: String?
        }
        struct Result: Decodable {
            let uids: [String]
            let articles: [String: Article]

            private struct DynamicKey: CodingKey {
                var stringValue: String
                init?(stringValue: String) { self.stringValue = stringValue }
                var intValue: Int? { nil }
                init?(intValue: Int) { return nil }
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: DynamicKey.self)
                let uidsKey = DynamicKey(stringValue: "uids")!
                uids = (try? container.decode([String].self, forKey: uidsKey)) ?? []
                var mapped: [String: Article] = [:]
                for key in container.allKeys where key.stringValue != "uids" {
                    if let article = try? container.decode(Article.self, forKey: key) {
                        mapped[key.stringValue] = article
                    }
                }
                articles = mapped
            }
        }
        let result: Result
    }

    func lookup(species: Species, region: String, terms: [String]) async -> Evidence {
        let baseReferences = curatedReferences(region: region)
        guard let searchURL = pubMedSearchURL(species: species, region: region, terms: terms) else {
            return Evidence(
                summary: "Local analysis completed. Live literature lookup could not be prepared; curated veterinary references are still available below.",
                references: baseReferences
            )
        }

        do {
            var request = URLRequest(url: searchURL)
            request.timeoutInterval = 12
            request.setValue("FergusonVetPilot/0.2", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let search = try JSONDecoder().decode(ESearchResponse.self, from: data)
            let ids = Array(search.esearchresult.idlist.prefix(4))
            guard !ids.isEmpty else {
                return Evidence(
                    summary: "Local analysis completed. PubMed returned no close veterinary literature matches for the current search terms; curated references are listed below.",
                    references: baseReferences
                )
            }

            guard let summaryURL = pubMedSummaryURL(ids: ids) else {
                return Evidence(summary: "Local analysis completed; PubMed matches were found but article details could not be loaded.", references: baseReferences)
            }

            var summaryRequest = URLRequest(url: summaryURL)
            summaryRequest.timeoutInterval = 12
            summaryRequest.setValue("FergusonVetPilot/0.2", forHTTPHeaderField: "User-Agent")
            let (summaryData, summaryResponse) = try await URLSession.shared.data(for: summaryRequest)
            guard let summaryHTTP = summaryResponse as? HTTPURLResponse, (200...299).contains(summaryHTTP.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode(ESummaryResponse.self, from: summaryData)
            let articles: [RadiologyAIReference] = ids.compactMap { id in
                guard let article = decoded.result.articles[id],
                      let title = article.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !title.isEmpty else { return nil }
                let details = [article.source, article.pubdate]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " • ")
                return RadiologyAIReference(
                    title: title,
                    url: "https://pubmed.ncbi.nlm.nih.gov/\(id)/",
                    sourceType: "PubMed",
                    relevance: details.isEmpty ? "Live veterinary/radiology literature match" : "Live literature match • \(details)"
                )
            }

            let total = Int(search.esearchresult.count) ?? articles.count
            let summary = "Local image analysis completed. Live PubMed cross-reference found \(total) matching record(s); the most relevant recent results available from the query are listed below. Literature matches add context but do not validate a diagnosis for this patient."
            return Evidence(summary: summary, references: articles + baseReferences)
        } catch {
            return Evidence(
                summary: "Local image analysis completed. Live PubMed cross-reference was unavailable (for example, no connection or service timeout), so the scan result below is based on the image measurements only. Curated veterinary references remain available.",
                references: baseReferences
            )
        }
    }

    private func pubMedSearchURL(species: Species, region: String, terms: [String]) -> URL? {
        let speciesTerms = species == .dog
            ? "(dog[Title/Abstract] OR canine[Title/Abstract] OR dogs[MeSH Terms])"
            : "(cat[Title/Abstract] OR feline[Title/Abstract] OR cats[MeSH Terms])"
        let radiologyTerms = "(radiograph*[Title/Abstract] OR radiography[MeSH Terms] OR x-ray[Title/Abstract])"

        let lowerRegion = region.lowercased()
        let anatomyTerms: String
        if lowerRegion.contains("thorax") || lowerRegion.contains("chest") || lowerRegion.contains("lung") {
            anatomyTerms = "(thorax[Title/Abstract] OR thoracic[Title/Abstract] OR chest[Title/Abstract] OR pulmonary[Title/Abstract])"
        } else if lowerRegion.contains("abdomen") || lowerRegion.contains("abdominal") || lowerRegion.contains("gi") {
            anatomyTerms = "(abdomen[Title/Abstract] OR abdominal[Title/Abstract] OR gastrointestinal[Title/Abstract])"
        } else {
            anatomyTerms = ""
        }

        let evidenceStopWords: Set<String> = [
            "veterinary", "radiograph", "radiographic", "radiography", "pattern", "image", "images", "canine", "feline", "dog", "dogs", "cat", "cats"
        ]
        let evidenceKeywords = Array(terms.prefix(4))
            .flatMap { phrase in
                phrase.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            }
            .filter { $0.count >= 4 && !evidenceStopWords.contains($0) }
        var seenKeywords = Set<String>()
        let uniqueKeywords = evidenceKeywords.filter { seenKeywords.insert($0).inserted }.prefix(6)
        let cleanEvidence = uniqueKeywords.map { "(\($0)[Title/Abstract])" }
        let evidenceGroup = cleanEvidence.isEmpty ? "" : "(" + cleanEvidence.joined(separator: " OR ") + ")"
        let queryParts = [speciesTerms, radiologyTerms, anatomyTerms, evidenceGroup].filter { !$0.isEmpty }
        let query = queryParts.joined(separator: " AND ")

        var components = URLComponents(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi")
        components?.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "retmode", value: "json"),
            URLQueryItem(name: "retmax", value: "4"),
            URLQueryItem(name: "sort", value: "relevance"),
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "tool", value: "FergusonVetPilot")
        ]
        return components?.url
    }

    private func pubMedSummaryURL(ids: [String]) -> URL? {
        var components = URLComponents(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi")
        components?.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "retmode", value: "json"),
            URLQueryItem(name: "id", value: ids.joined(separator: ",")),
            URLQueryItem(name: "tool", value: "FergusonVetPilot")
        ]
        return components?.url
    }

    private func curatedReferences(region: String) -> [RadiologyAIReference] {
        var references = [
            RadiologyAIReference(
                title: "American College of Veterinary Radiology — Radiology",
                url: "https://acvr.org/how-we-do-it/types-of-imaging-therapy/radiology/",
                sourceType: "Veterinary radiology specialty reference",
                relevance: "ACVR veterinary radiography overview and imaging examples"
            ),
            RadiologyAIReference(
                title: "Cornell University College of Veterinary Medicine — Imaging Service",
                url: "https://www.vet.cornell.edu/hospitals/services/imaging-service",
                sourceType: "Veterinary teaching-hospital imaging reference",
                relevance: "Board-certified veterinary imaging service and radiography context"
            ),
            RadiologyAIReference(
                title: "MSD Veterinary Manual — Radiography of Animals",
                url: "https://www.msdvetmanual.com/clinical-pathology-and-procedures/diagnostic-imaging/radiography-of-animals",
                sourceType: "Veterinary reference",
                relevance: "General veterinary radiography technique and interpretation context"
            ),
            RadiologyAIReference(
                title: "VetXRay — canine/feline thoracic radiograph dataset",
                url: "https://doi.org/10.5281/zenodo.19051776",
                sourceType: "Veterinary AI dataset",
                relevance: "Radiologist-annotated canine/feline thoracic X-ray research resource"
            )
        ]

        if region.lowercased().contains("thorax") || region.lowercased().contains("chest") {
            references.append(
                RadiologyAIReference(
                    title: "Automatic classification of canine thoracic radiographs using deep learning",
                    url: "https://pubmed.ncbi.nlm.nih.gov/33597566/",
                    sourceType: "Peer-reviewed veterinary AI research",
                    relevance: "Canine thoracic radiograph classification research"
                )
            )
        }
        return references
    }
}
