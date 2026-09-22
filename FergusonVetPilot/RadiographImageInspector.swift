import Foundation
import UIKit
import Vision
import CoreGraphics
import ImageIO

struct RadiographInspection: Equatable {
    enum Verdict: String {
        case likelyRadiograph = "Likely radiograph"
        case uncertain = "Uncertain"
        case notRadiograph = "Does not look like a radiograph"
    }

    let verdict: Verdict
    let score: Double
    let grayRatio: Double
    let contrast: Double
    let labels: [String]
    let explanation: String

    var canAnalyze: Bool { verdict != .notRadiograph }
}

enum RadiographImageInspector {
    static func inspect(_ image: UIImage) async -> RadiographInspection {
        async let classifications = classify(image)
        let metrics = pixelMetrics(image)
        let labels = await classifications

        let normalized = labels.map { ($0.0.lowercased(), Double($0.1)) }
        let xrayConfidence = normalized
            .filter { label, _ in
                label.contains("x-ray") ||
                label.contains("xray") ||
                label.contains("radiograph") ||
                label.contains("roentgen")
            }
            .map(\.1)
            .max() ?? 0

        let anatomyConfidence = normalized
            .filter { label, _ in
                label.contains("skeleton") ||
                label.contains("rib") ||
                label.contains("spine") ||
                label.contains("bone")
            }
            .map(\.1)
            .max() ?? 0

        let grayComponent = max(0, min(1, (metrics.grayRatio - 0.65) / 0.35))
        let contrastComponent = max(0, min(1, metrics.contrast / 0.24))
        let visionComponent = min(1, xrayConfidence * 2.2 + anatomyConfidence * 0.35)
        let appearanceComponent = grayComponent * 0.58 + contrastComponent * 0.42
        var score = min(1, visionComponent * 0.50 + appearanceComponent * 0.50)

        // Apple's generic image classifier can miss genuine veterinary radiographs.
        // Strong monochrome appearance plus broad tonal separation is therefore allowed
        // to support the input-type gate. This does not validate anatomy or disease.
        if metrics.grayRatio >= 0.96 && metrics.contrast >= 0.15 {
            score = max(score, min(0.90, 0.70 + (metrics.contrast - 0.15) * 1.25))
        }

        let verdict: RadiographInspection.Verdict
        if (xrayConfidence >= 0.08 && metrics.grayRatio >= 0.65) || score >= 0.67 {
            verdict = .likelyRadiograph
        } else if metrics.grayRatio >= 0.82 && metrics.contrast >= 0.08 {
            verdict = .uncertain
        } else {
            verdict = .notRadiograph
        }

        let topLabels = labels.prefix(6).map { "\($0.0) \(Int($0.1 * 100))%" }
        let explanation: String
        switch verdict {
        case .likelyRadiograph:
            explanation = "The image has radiograph-like visual characteristics. AI review can proceed, but this check does not verify projection, anatomy, or diagnostic quality."
        case .uncertain:
            explanation = "The image is mostly grayscale with radiograph-like contrast, but the on-device classifier could not confidently identify it as an X-ray. Review it before continuing."
        case .notRadiograph:
            explanation = "The image does not have enough radiograph-like characteristics. Try a clearer X-ray image rather than a regular photograph or screenshot."
        }

        return RadiographInspection(
            verdict: verdict,
            score: score,
            grayRatio: metrics.grayRatio,
            contrast: metrics.contrast,
            labels: topLabels,
            explanation: explanation
        )
    }

    static func pixelMetrics(_ image: UIImage) -> (grayRatio: Double, contrast: Double) {
        let width = 64
        let height = 64
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let normalized = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: width, height: height))
            image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        guard let cgImage = normalized.cgImage else { return (0, 0) }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return (0, 0)
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var grayCount = 0
        var luminances = [Double]()
        luminances.reserveCapacity(width * height)

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[index]) / 255
            let g = Double(pixels[index + 1]) / 255
            let b = Double(pixels[index + 2]) / 255
            let chroma = max(r, g, b) - min(r, g, b)
            if chroma < 0.09 { grayCount += 1 }
            luminances.append(0.2126 * r + 0.7152 * g + 0.0722 * b)
        }

        let count = Double(max(1, luminances.count))
        let mean = luminances.reduce(0, +) / count
        let variance = luminances.reduce(0) { $0 + pow($1 - mean, 2) } / count
        return (
            grayRatio: Double(grayCount) / count,
            contrast: sqrt(variance)
        )
    }

    private static func visionOrientation(for image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    private static func classify(_ image: UIImage) async -> [(String, Float)] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: Self.visionOrientation(for: image), options: [:])

                do {
                    try handler.perform([request])
                    let values = (request.results ?? []).prefix(12).map {
                        ($0.identifier, $0.confidence)
                    }
                    continuation.resume(returning: values)
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }
}
