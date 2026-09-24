import Foundation
import Speech
import AVFoundation

@MainActor
final class ScribeSpeech {
    private var recognition: SFSpeechRecognitionTask?
    private var timeout: Task<Void, Never>?
    private var continuation: CheckedContinuation<String, Error>?
    private func finish(_ result: Result<String, Error>) {
        guard let continuation else { return }; self.continuation = nil
        timeout?.cancel(); timeout = nil; recognition?.cancel(); recognition = nil
        continuation.resume(with: result)
    }
    func transcribe(_ file: URL, locale: String, patientNames: [String]) async throws -> String {
        let authorization = await withCheckedContinuation { value in SFSpeechRecognizer.requestAuthorization { value.resume(returning: $0) } }
        guard authorization == .authorized else { throw ScribeError.invalid("Speech recognition is disabled. Enable it in Settings or enter the transcript manually.") }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            throw ScribeError.invalid("On-device speech recognition is unavailable for this language or device. Choose another supported language, enter text manually, or use configured cloud transcription.")
        }
        let request = SFSpeechURLRecognitionRequest(url: file)
        request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = false
        request.taskHint = .dictation; request.contextualStrings = patientNames
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { value in
                continuation = value
                recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    Task { @MainActor in
                        if let result, result.isFinal { self?.finish(.success(result.bestTranscription.formattedString)) }
                        else if let error { self?.finish(.failure(error)) }
                    }
                }
                timeout = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 90_000_000_000)
                    guard !Task.isCancelled else { return }
                    self?.finish(.failure(ScribeError.invalid("Speech recognition timed out. The recording is preserved; retry or enter text manually.")))
                }
            }
        } onCancel: { Task { @MainActor in self.finish(.failure(CancellationError())) } }
    }
}

enum ScribeAudioChunks {
    static func export(_ source: URL) async throws -> [URL] {
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0, duration <= 7200 else { throw ScribeError.invalid("Audio is empty, unreadable, or longer than two hours.") }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("VetPilotSpeech-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var result: [URL] = []
        do {
            for start in stride(from: 0.0, to: duration, by: 45.0) {
                try Task.checkCancellation()
                guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else { throw ScribeError.invalid("Audio could not be prepared for transcription.") }
                let url = folder.appendingPathComponent("\(result.count).m4a")
                exporter.outputURL = url; exporter.outputFileType = .m4a
                exporter.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: CMTime(seconds: min(45, duration - start), preferredTimescale: 600))
                await withCheckedContinuation { value in exporter.exportAsynchronously { value.resume() } }
                guard exporter.status == .completed else { throw exporter.error ?? ScribeError.invalid("Audio preparation failed.") }
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
                result.append(url)
            }
            return result
        } catch { try? FileManager.default.removeItem(at: folder); throw error }
    }
}

extension ScribeStore {
    func transcribe(_ id: UUID, cloud: Bool, account: VetPilotAccount) async {
        guard !accountLocked, var value = encounter(id) else { return }
        busy = true; defer { busy = false; progress = "" }
        let accountID = account.userID
        do {
            guard !value.recordingFiles.isEmpty else { throw ScribeError.invalid("Record audio first, or enter a transcript and tap Create notes from text.") }
            let speech = ScribeSpeech(); var texts: [String] = []
            for (fileIndex, filename) in value.recordingFiles.enumerated() {
                let chunks = try await ScribeAudioChunks.export(audioURL(filename))
                defer { if let first = chunks.first { try? FileManager.default.removeItem(at: first.deletingLastPathComponent()) } }
                for (index, chunk) in chunks.enumerated() {
                    progress = "Transcribing recording \(fileIndex + 1), part \(index + 1) of \(chunks.count)…"
                    let text: String
                    if cloud {
                        let data = try Data(contentsOf: chunk)
                        let response = try await account.request(path: "functions/v1/vetpilot-scribe", method: "POST", body: ["action": "transcribe", "audio": data.base64EncodedString(), "language": String(value.locale.prefix(2))])
                        struct Response: Decodable { let text: String }
                        text = try JSONDecoder().decode(Response.self, from: response).text
                    } else { text = try await speech.transcribe(chunk, locale: value.locale, patientNames: value.patients.flatMap(\.spokenNames)) }
                    texts.append(text)
                    // Save each completed chunk, so a later failure never loses the entire transcript.
                    value.transcript = texts.joined(separator: "\n"); value.updatedAt = Date(); try save(value)
                }
            }
            guard account.userID == accountID else { throw ScribeError.invalid("Account changed while processing. Saved local data is preserved.") }
            try await createNotes(value, cloud: cloud, account: account)
        } catch { self.error = error.localizedDescription }
    }
    func draftText(_ id: UUID, cloud: Bool, account: VetPilotAccount) async {
        guard !accountLocked, let value = encounter(id) else { return }
        busy = true; defer { busy = false; progress = "" }
        do { try await createNotes(value, cloud: cloud, account: account) } catch { self.error = error.localizedDescription }
    }
    private func createNotes(_ encounter: ScribeEncounter, cloud: Bool, account: VetPilotAccount) async throws {
        guard !encounter.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ScribeError.invalid("No speech was recognized. Check the recording or enter the transcript manually.") }
        progress = "Creating draft notes…"
        var value = encounter
        if cloud {
            let patients = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value.patients))
            let data = try await account.request(path: "functions/v1/vetpilot-scribe", method: "POST", body: ["action": "draft", "transcript": value.transcript, "patients": patients, "historyOnly": value.historyOnly])
            value = try JSONDecoder().decode(ScribeCloudDraft.self, from: data).applying(to: value)
        } else { value.draftFromTranscript() }
        try save(value)
        if account.configured, let owner = account.userID {
            let originalDirectory = directory
            do {
                let version = try await ScribeCloud.upload(value, account: account)
                guard account.userID == owner, directory == originalDirectory else { return }
                value.syncVersion = version; value.syncedAt = Date(); try save(value)
                syncStatus = "Notes uploaded"
            } catch { syncStatus = "Notes saved locally; upload pending — " + error.localizedDescription }
        }
    }
}

@MainActor
enum ScribeCloud {
    struct Row: Decodable { var id: UUID; var version: Int; var payload: ScribeEncounter }
    static func upload(_ encounter: ScribeEncounter, account: VetPilotAccount) async throws -> Int {
        var copy = encounter; copy.recordingFiles = [] // Audio remains on this device.
        let payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(copy))
        let data = try await account.request(path: "rest/v1/rpc/save_scribe_encounter", method: "POST", body: ["encounter_id": encounter.id.uuidString, "expected_version": encounter.syncVersion, "encounter_payload": payload])
        return try JSONDecoder().decode(Int.self, from: data)
    }
    static func download(account: VetPilotAccount) async throws -> [Row] {
        let data = try await account.request(path: "rest/v1/scribe_encounters?select=id,version,payload&order=updated_at.desc&limit=500")
        return try JSONDecoder().decode([Row].self, from: data)
    }
    static func translation(_ note: SOAPNote, language: String, account: VetPilotAccount) async throws -> NoteTranslation {
        guard note.finalizedAt != nil else { throw ScribeError.invalid("Review and finalize the source note before translation.") }
        let data = try await account.request(path: "functions/v1/vetpilot-scribe", method: "POST", body: ["action": "translate", "text": note.plainText, "language": language])
        struct Response: Decodable { var text: String }
        return NoteTranslation(language: language, text: try JSONDecoder().decode(Response.self, from: data).text, sourceText: note.plainText)
    }
}
