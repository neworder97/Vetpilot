import SwiftUI
import PhotosUI
import UIKit
import Foundation

struct RadiologyView: View {
    @State private var photoItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var showSecondLook = false
    @State private var showUncertainRadiographAlert = false
    @State private var species: Species = .dog
    @State private var studyRegion = ""
    @State private var clinicalHistory = ""
    @State private var status = "No image loaded."
    @State private var aiResult: RadiologyAIResult?
    @State private var isAnalyzing = false
    @State private var isInspecting = false
    @State private var inspection: RadiographInspection?
    @StateObject private var reviewStore = RadiologyReviewStore()

    @AppStorage("vetpilot.radiology.scanCount") private var scanCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Radiology AI Second Look")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.blue)

                        Text("Load a dog/cat radiograph for a live second look. VetPilot measures the actual image on-device, reports broad radiographic pattern observations, and uses Wi‑Fi/cellular data for a free live veterinary-literature cross-reference when available. Include the projection (for example lateral or VD/DV) in the study field when known.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.88))
                            .frame(height: 280)

                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 270)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "waveform.path.ecg.rectangle")
                                    .font(.system(size: 42))
                                Text("No radiograph loaded")
                            }
                            .foregroundStyle(.white.opacity(0.75))
                        }

                        if isAnalyzing || isInspecting {
                            ZStack {
                                Color.black.opacity(0.55)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))

                                VStack(spacing: 10) {
                                    ProgressView()
                                        .tint(.white)

                                    Text(isInspecting ? "Checking whether this looks like an X-ray…" : "Measuring X-ray + checking veterinary literature…")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }

                    HStack {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera) || isAnalyzing || isInspecting)

                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Import X-ray", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isAnalyzing || isInspecting)
                    }

                    if let inspection {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(
                                    inspection.verdict.rawValue,
                                    systemImage: inspection.verdict == .likelyRadiograph
                                        ? "checkmark.circle.fill"
                                        : (inspection.verdict == .uncertain ? "questionmark.circle.fill" : "xmark.octagon.fill")
                                )
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(inspection.verdict == .likelyRadiograph ? Color.green : AppTheme.orange)
                                .accessibilityIdentifier("radiology.xrayGate")

                                Spacer()

                                Text("Precheck \(Int(inspection.score * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Text(inspection.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !inspection.labels.isEmpty {
                                Text("On-device labels: \(inspection.labels.joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .vetCard()

                    }

                    Picker("Species", selection: $species) {
                        ForEach(Species.allCases) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isAnalyzing || isInspecting)

                    TextField("Study/region + view — thorax lateral, thorax VD, abdomen…", text: $studyRegion)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isAnalyzing || isInspecting)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Clinical history / question")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        TextEditor(text: $clinicalHistory)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(AppTheme.pale, in: RoundedRectangle(cornerRadius: 12))
                            .disabled(isAnalyzing || isInspecting)
                    }

                    Button {
                        runSecondLook()
                    } label: {
                        if isInspecting {
                            HStack {
                                ProgressView()
                                Text("Checking X-ray…")
                            }
                            .frame(maxWidth: .infinity)
                        } else if isAnalyzing {
                            HStack {
                                ProgressView()
                                Text("Analyzing…")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Label("AI Scan / second look", systemImage: "sparkles.rectangle.stack")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAnalyzing || isInspecting || inspection?.verdict == .notRadiograph)
                    .accessibilityIdentifier("radiology.secondLook")

                    HStack {
                        Label("On-device analysis + live PubMed", systemImage: "network")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Label("\(scanCount) scan(s)", systemImage: "viewfinder.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(
                            status.hasPrefix("Rejected") ||
                            status.contains("setup") ||
                            status.contains("Uncertain")
                            ? AppTheme.orange
                            : .secondary
                        )
                        .vetCard()

                    Text("Privacy: image measurements stay on this iPhone. The selected X-ray itself is not uploaded to PubMed or a third-party AI service; only text search terms are sent for the live literature lookup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCamera, onDismiss: {
                if let image {
                    aiResult = nil
                    validateLoadedImage(image)
                }
            }) {
                CameraPicker(image: $image)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showSecondLook) {
                if let image, let aiResult {
                    RadiologySecondLookSheet(
                        image: image,
                        species: species,
                        studyRegion: studyRegion,
                        clinicalHistory: clinicalHistory,
                        scanNumber: scanCount,
                        analysis: aiResult,
                        store: reviewStore
                    )
                }
            }
            .onChange(of: photoItem) { _, newValue in
                guard let newValue else { return }

                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            image = uiImage
                            aiResult = nil
                        }
                        validateLoadedImage(uiImage)
                    } else {
                        await MainActor.run {
                            status = "Could not load that image. Try another file."
                        }
                    }
                }
            }
            .alert("X-ray check is uncertain", isPresented: $showUncertainRadiographAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Analyze anyway") {
                    if let image, let inspection {
                        beginAIAnalysis(image: image, inspection: inspection)
                    }
                }
            } message: {
                Text("VetPilot could not confidently identify this image as a radiograph. Continue only if you have visually confirmed that it is an X-ray.")
            }
        }
    }

    private func runSecondLook() {
        guard let image else {
            status = "Load a radiograph first."
            return
        }

        Task {
            let currentInspection: RadiographInspection

            if let inspection {
                currentInspection = inspection
            } else {
                await MainActor.run {
                    isInspecting = true
                    status = "Checking whether this looks like an X-ray…"
                }

                currentInspection = await RadiographImageInspector.inspect(image)

                await MainActor.run {
                    self.inspection = currentInspection
                    isInspecting = false
                }
            }

            await MainActor.run {
                switch currentInspection.verdict {
                case .notRadiograph:
                    status = "Rejected: this image does not look enough like a radiograph. Try a clearer X-ray image."
                case .uncertain:
                    status = "Uncertain X-ray check. Confirm the image before continuing analysis."
                    showUncertainRadiographAlert = true
                case .likelyRadiograph:
                    beginAIAnalysis(image: image, inspection: currentInspection)
                }
            }
        }
    }

    private func validateLoadedImage(_ image: UIImage) {
        inspection = nil
        isInspecting = true
        status = "Checking whether this looks like an X-ray…"

        Task {
            let result = await RadiographImageInspector.inspect(image)

            await MainActor.run {
                inspection = result
                isInspecting = false

                switch result.verdict {
                case .likelyRadiograph:
                    status = "Likely X-ray. Tap Scan / second look for live image analysis."
                case .uncertain:
                    status = "Uncertain X-ray check. You can visually confirm it and choose Analyze anyway."
                case .notRadiograph:
                    status = "Rejected: this image does not look enough like a radiograph."
                }
            }
        }
    }

    private func beginAIAnalysis(image: UIImage, inspection: RadiographInspection) {
        isAnalyzing = true
        status = "Measuring the X-ray and cross-referencing veterinary literature…"

        let prior = reviewStore.priorConfirmedContext(species: species, region: studyRegion)

        Task {
            do {
                let result = try await RadiologyAIService.shared.analyze(
                    image: image,
                    species: species,
                    studyRegion: studyRegion,
                    clinicalHistory: clinicalHistory,
                    priorConfirmedCases: prior,
                    inspection: inspection
                )

                await MainActor.run {
                    isAnalyzing = false
                    aiResult = result

                    guard result.isRadiograph else {
                        status = "Rejected by the X-ray check (\(result.radiographConfidence) confidence): \(result.radiographAssessment)"
                        return
                    }

                    scanCount += 1
                    status = "Live review complete. Results are measured pattern observations and broad possibilities, not diagnoses."
                    showSecondLook = true
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    status = error.localizedDescription
                }
            }
        }
    }

}

private struct RadiologyCaseMemory: Identifiable, Codable {
    let id: UUID
    let date: Date
    let species: String
    let region: String
    let confirmedFindings: String
    let aiBestGuess: String?

    init(species: Species, region: String, confirmedFindings: String, aiBestGuess: String?) {
        self.id = UUID()
        self.date = Date()
        self.species = species.rawValue
        self.region = region.trimmingCharacters(in: .whitespacesAndNewlines)
        self.confirmedFindings = confirmedFindings.trimmingCharacters(in: .whitespacesAndNewlines)
        self.aiBestGuess = aiBestGuess
    }
}

@MainActor
private final class RadiologyReviewStore: ObservableObject {
    @Published private(set) var cases: [RadiologyCaseMemory] = []
    private let key = "ferguson.vetpilot.radiology-case-memory.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RadiologyCaseMemory].self, from: data) else {
            return
        }
        cases = decoded
    }

    func save(species: Species, region: String, confirmedFindings: String, aiBestGuess: String?) {
        let memory = RadiologyCaseMemory(
            species: species,
            region: region,
            confirmedFindings: confirmedFindings,
            aiBestGuess: aiBestGuess
        )
        cases.insert(memory, at: 0)

        if cases.count > 50 {
            cases = Array(cases.prefix(50))
        }

        persist()
    }

    func priorConfirmedContext(species: Species, region: String) -> String {
        let regionNeedle = normalize(region)

        let filtered = cases.filter { item in
            guard item.species == species.rawValue else { return false }
            if regionNeedle.isEmpty { return true }

            let candidate = normalize(item.region)
            guard !candidate.isEmpty else { return false }
            return candidate.contains(regionNeedle) || regionNeedle.contains(candidate)
        }

        return filtered.prefix(8).map { item in
            let regionText = item.region.isEmpty ? "unspecified region" : item.region
            let aiText = item.aiBestGuess.map { " | prior AI guess: \($0)" } ?? ""
            return "\(item.species) \(regionText): clinician-confirmed \(item.confirmedFindings)\(aiText)"
        }
        .joined(separator: "\n")
    }

    func similarCaseCount(region: String) -> Int {
        let needle = normalize(region)
        guard !needle.isEmpty else { return cases.count }

        return cases.filter {
            let candidate = normalize($0.region)
            guard !candidate.isEmpty else { return false }
            return candidate.contains(needle) || needle.contains(candidate)
        }.count
    }

    func mostRecentConfirmedNote(region: String) -> String? {
        let needle = normalize(region)

        if needle.isEmpty {
            return cases.first?.confirmedFindings
        }

        return cases.first {
            let candidate = normalize($0.region)
            guard !candidate.isEmpty else { return false }
            return candidate.contains(needle) || needle.contains(candidate)
        }?.confirmedFindings
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cases) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private struct RadiologySecondLookSheet: View {
    let image: UIImage
    let species: Species
    let studyRegion: String
    let clinicalHistory: String
    let scanNumber: Int
    let analysis: RadiologyAIResult
    @ObservedObject var store: RadiologyReviewStore

    @Environment(\.dismiss) private var dismiss
    @State private var reviewedItems: Set<String> = []
    @State private var clinicianNotes = ""
    @State private var saved = false

    private var regionName: String {
        let trimmed = studyRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unspecified region" : trimmed
    }

    private var checklist: [String] {
        RadiologyReviewGuide.checklist(for: studyRegion)
    }

    private var topGuessSummary: String? {
        analysis.differentials.first?.name
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Loaded study") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    LabeledContent("Species", value: species.rawValue)
                    LabeledContent("Region", value: regionName)
                    LabeledContent("Scan", value: "#\(scanNumber)")
                    LabeledContent("AI X-ray check", value: "\(analysis.radiographConfidence.capitalized) confidence")

                    Text(analysis.radiographAssessment)
                        .font(.footnote)

                    if !clinicalHistory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("History")
                                .font(.caption.bold())
                            Text(clinicalHistory)
                        }
                    }
                }

                Section("Automated pattern review — not a diagnosis") {
                    Text(analysis.studyAssessment)
                        .font(.subheadline.weight(.semibold))

                    Text("Image quality: \(analysis.imageQuality)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if analysis.differentials.isEmpty {
                        Text("The analyzer did not produce a defensible broad pattern classification from this image.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(analysis.differentials.enumerated()), id: \.element.id) { index, item in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .top) {
                                Text("\(index + 1). \(item.name)")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.blue)
                                    .accessibilityIdentifier(
                                        index == 0
                                        ? "radiology.ai.topDifferential"
                                        : "radiology.ai.differential.\(index)"
                                    )

                                Spacer()

                                ConfidenceBadge(value: item.confidence)
                            }

                            Text(item.whyItFits)

                            if !item.whatArguesAgainst.isEmpty {
                                Text("Against / missing: \(item.whatArguesAgainst)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                if let url = RadiologyAIService.googleImagesURL(
                                    species: species,
                                    region: studyRegion,
                                    searchTerms: [item.name] + analysis.searchTerms
                                ) {
                                    Link("Similar X-rays", destination: url)
                                }

                                if let url = RadiologyAIService.vinSearchURL(
                                    species: species,
                                    region: studyRegion,
                                    searchTerms: [item.name] + analysis.searchTerms
                                ) {
                                    Link("Search VIN", destination: url)
                                }
                            }
                            .font(.caption.weight(.semibold))
                        }
                        .padding(.vertical, 4)
                    }

                    Text("These are broad automated pattern possibilities derived from the actual image measurements. Confidence labels are qualitative and are not calibrated disease probabilities.")
                        .font(.footnote.bold())
                        .foregroundStyle(AppTheme.orange)
                }

                Section("What the analyzer measures") {
                    if analysis.findings.isEmpty {
                        Text("No specific image-level pattern was reported.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(analysis.findings) { finding in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top) {
                                Text(finding.observation)
                                    .font(.subheadline.weight(.semibold))

                                Spacer()

                                ConfidenceBadge(value: finding.confidence)
                            }

                            Text(finding.explanation)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !analysis.urgentFlags.isEmpty {
                    Section("Potential urgent flags") {
                        ForEach(analysis.urgentFlags, id: \.self) { flag in
                            Label(flag, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.orange)
                        }
                    }
                }

                Section("Web / veterinary cross-reference") {
                    Text(analysis.crossReferenceSummary)

                    ForEach(analysis.references) { reference in
                        if let url = URL(string: reference.url) {
                            Link(destination: url) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(reference.title)
                                        .font(.subheadline.weight(.semibold))

                                    Text("\(reference.sourceType) • \(reference.relevance)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if let url = RadiologyAIService.googleImagesURL(
                        species: species,
                        region: studyRegion,
                        searchTerms: analysis.searchTerms
                    ) {
                        Link("Google Images — similar veterinary X-rays", destination: url)
                    }

                    if let url = RadiologyAIService.vinSearchURL(
                        species: species,
                        region: studyRegion,
                        searchTerms: analysis.searchTerms
                    ) {
                        Link("VIN search for these findings", destination: url)
                    }

                    Link("Open VIN", destination: URL(string: "https://www.vin.com/")!)
                    Link(
                        "MSD Veterinary Manual — Radiography",
                        destination: URL(string: "https://www.msdvetmanual.com/clinical-pathology-and-procedures/diagnostic-imaging/radiography-of-animals")!
                    )

                    Text("VIN material that requires a login is not bypassed or scraped. Similar-image links are a visual comparison aid, not evidence that two cases have the same disease.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Systematic second-look checklist") {
                    ForEach(checklist, id: \.self) { item in
                        Button {
                            if reviewedItems.contains(item) {
                                reviewedItems.remove(item)
                            } else {
                                reviewedItems.insert(item)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: reviewedItems.contains(item) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(reviewedItems.contains(item) ? Color.green : Color.secondary)

                                Text(item)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Teach VetPilot from the confirmed outcome") {
                    Text("Every scan is counted, but automated possibilities are not treated as truth. When you save the veterinarian/radiologist-confirmed outcome, VetPilot adds it to local case memory for future review context.")
                        .font(.footnote)

                    Text("VetPilot has \(store.similarCaseCount(region: studyRegion)) confirmed reviewed case(s) with similar region metadata.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let prior = store.mostRecentConfirmedNote(region: studyRegion) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Most recent confirmed note")
                                .font(.caption.bold())
                            Text(prior)
                        }
                    }

                    TextEditor(text: $clinicianNotes)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.25))
                        )
                        .accessibilityIdentifier("radiology.confirmedNotes")

                    Button {
                        store.save(
                            species: species,
                            region: studyRegion,
                            confirmedFindings: clinicianNotes,
                            aiBestGuess: topGuessSummary
                        )
                        saved = true
                    } label: {
                        Label(
                            saved ? "Saved to local case memory" : "Save confirmed findings",
                            systemImage: saved ? "checkmark.circle.fill" : "brain.head.profile"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(clinicianNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saved)
                }

                if !analysis.limitations.isEmpty {
                    Section("Limitations") {
                        ForEach(analysis.limitations, id: \.self) { item in
                            Text(item)
                        }
                    }
                }

                Section {
                    Text("Second-look decision support only. Use a veterinarian or veterinary radiologist for clinical interpretation and treatment decisions, especially for poor-quality studies, subtle findings, or potentially urgent abnormalities.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("X-Ray Second Look")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("radiology.secondLook.done")
                }
            }
        }
    }
}

private struct ConfidenceBadge: View {
    let value: String

    var body: some View {
        Text(value.uppercased())
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
    }

    private var background: Color {
        switch value.lowercased() {
        case "high":
            return Color.green.opacity(0.18)
        case "moderate":
            return AppTheme.orange.opacity(0.18)
        default:
            return Color.secondary.opacity(0.15)
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
