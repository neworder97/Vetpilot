import SwiftUI
import VisionKit
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    let onRead: (String) -> Void
    let onError: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onRead: onRead, onError: onError) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced, recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false, isPinchToZoomEnabled: true, isGuidanceEnabled: true, isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        DispatchQueue.main.async { [weak controller, weak coordinator = context.coordinator] in
            guard let controller, let coordinator, !coordinator.finished else { return }
            do { try controller.startScanning() } catch { coordinator.onError("Unable to start scanning. Paste the sharing link instead.") }
        }
        return controller
    }
    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) { coordinator.finished = true; controller.stopScanning(); controller.delegate = nil }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var finished = false
        let onRead: (String) -> Void
        let onError: (String) -> Void
        init(onRead: @escaping (String) -> Void, onError: @escaping (String) -> Void) { self.onRead = onRead; self.onError = onError }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !finished else { return }; for item in addedItems { if case .barcode(let barcode) = item, let text = barcode.payloadStringValue { finished = true; dataScanner.stopScanning(); onRead(text); return } }
        }
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            guard !finished else { return }; finished = true; dataScanner.stopScanning(); onError("Camera scanning unavailable. Paste the sharing link instead.")
        }
    }
}
