import Foundation
import Combine
import AVFoundation

@MainActor
final class ScribeStore: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var encounters: [ScribeEncounter] = []
    @Published private(set) var activeID: UUID?
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsed: Double = 0
    @Published var busy = false
    @Published var progress = ""
    @Published var error: String?
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var root: URL
    private var scope = "guest"
    private var loadFailed = false
    var hasActiveRecording: Bool { activeID != nil }
    var accountLocked: Bool { hasActiveRecording || busy }
    var directory: URL { root.appendingPathComponent(scope, isDirectory: true) }
    private var indexURL: URL { directory.appendingPathComponent("encounters.json") }

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("VetPilot/Scribe", isDirectory: true)
        super.init(); load()
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) ?? 0
            Task { @MainActor in
                guard type == AVAudioSession.InterruptionType.began.rawValue, let self, self.isRecording else { return }
                self.pause(); self.error = "Recording paused by an audio interruption. Check the microphone and tap Resume when ready."
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 0
            Task { @MainActor in
                guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue, let self, self.isRecording else { return }
                self.pause(); self.error = "The microphone connection changed. Recording is paused; check the microphone before resuming."
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stop(); self?.error = "Audio services restarted. The saved recording is available; start a new recording to continue." }
        })
    }

    func switchAccount(_ id: UUID?) throws {
        guard !accountLocked else { throw ScribeError.invalid("Stop recording and finish processing before changing accounts.") }
        scope = id?.uuidString.lowercased() ?? "guest"; load()
    }
    private func load() {
        encounters = []; loadFailed = false
        do {
            guard FileManager.default.fileExists(atPath: indexURL.path) else { return }
            let values = try JSONDecoder().decode([ScribeEncounter].self, from: Data(contentsOf: indexURL))
            guard Set(values.map(\.id)).count == values.count else { throw ScribeError.invalid("Duplicate encounter IDs.") }
            encounters = try values.map { try $0.validated() }
        } catch { loadFailed = true; self.error = "Saved notes could not be read. The original files were preserved; saving is disabled until recovery." }
    }
    private func commit(_ values: [ScribeEncounter]) throws {
        guard !loadFailed else { throw ScribeError.invalid("Stored notes need recovery before saving.") }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var folder = directory; var attributes = URLResourceValues(); attributes.isExcludedFromBackup = true; try folder.setResourceValues(attributes)
        try JSONEncoder().encode(values).write(to: indexURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        encounters = values
    }
    func save(_ encounter: ScribeEncounter) throws {
        var valid = try encounter.validated(); var values = encounters
        if let old = self.encounter(valid.id), old.transcript != valid.transcript || old.patients != valid.patients {
            for i in valid.notes.indices { valid.notes[i].edited() }
            valid.updatedAt = Date()
        }
        if let i = values.firstIndex(where: { $0.id == valid.id }) { values[i] = valid } else { values.insert(valid, at: 0) }
        try commit(values)
    }
    func encounter(_ id: UUID) -> ScribeEncounter? { encounters.first { $0.id == id } }
    func audioURL(_ filename: String) -> URL { directory.appendingPathComponent(filename) }
    func delete(_ id: UUID) throws {
        guard activeID != id, !busy else { throw ScribeError.invalid("Stop recording or processing before deleting.") }
        let files = encounter(id)?.recordingFiles ?? []
        try commit(encounters.filter { $0.id != id })
        for file in files { try? FileManager.default.removeItem(at: audioURL(file)) }
    }
    func deleteAudio(_ id: UUID) throws {
        guard activeID != id, !busy, var value = encounter(id) else { throw ScribeError.invalid("Stop recording or processing before removing audio.") }
        let files = value.recordingFiles; value.recordingFiles = []; value.updatedAt = Date(); try save(value)
        for file in files { try? FileManager.default.removeItem(at: audioURL(file)) }
    }
    func clearLocalAccount() throws {
        guard !accountLocked else { throw ScribeError.invalid("Stop recording or processing first.") }
        try FileManager.default.removeItem(at: directory)
        encounters = []; loadFailed = false
    }
    func start(_ id: UUID, consent: Bool) async {
        guard !accountLocked, consent, var value = encounter(id) else { error = "Confirm recording consent and choose a saved encounter."; return }
        busy = true; defer { busy = false }
        let allowed = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard allowed else { error = "Microphone access is disabled. Enable it for VetPilot in iPhone Settings."; return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            let filename = "\(id.uuidString)-\(UUID().uuidString).m4a"
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let audio = try AVAudioRecorder(url: audioURL(filename), settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64000])
            audio.delegate = self
            guard audio.prepareToRecord() else { throw ScribeError.invalid("The microphone could not prepare a recording.") }
            value.recordingFiles.append(filename); value.consentAt = Date(); value.updatedAt = Date()
            try save(value)
            guard audio.record() else { throw ScribeError.invalid("Recording could not start. No audio is being captured.") }
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: audioURL(filename).path)
            recorder = audio; activeID = id; elapsed = value.recordedSeconds; isRecording = true; isPaused = false
            let previous = value.recordedSeconds
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let recorder = self.recorder else { return }
                    self.elapsed = previous + recorder.currentTime
                    if self.isRecording && !recorder.isRecording { self.pause(); self.error = "Audio capture stopped unexpectedly. Check the microphone before resuming." }
                    if Int(self.elapsed) % 10 == 0 { self.checkpoint() }
                }
            }
        } catch { self.error = error.localizedDescription; stop() }
    }
    private func checkpoint() {
        guard let id = activeID, var value = encounter(id) else { return }
        value.recordedSeconds = elapsed; value.updatedAt = Date()
        do {
            try save(value)
            let capacity = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? Int64.max
            if capacity < 5_000_000 { pause(); error = "Storage is almost full. Recording is paused; free space before resuming." }
        } catch { recorder?.pause(); isRecording = false; isPaused = true; self.error = "Recording paused because notes could not be saved: \(error.localizedDescription)" }
    }
    func pause() { recorder?.pause(); isRecording = false; isPaused = activeID != nil }
    func resume() {
        guard activeID != nil else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            guard recorder?.record() == true else { throw ScribeError.invalid("The microphone could not resume. Stop and start a new recording.") }
            isRecording = true; isPaused = false
        } catch { self.error = error.localizedDescription }
    }
    func stop() {
        checkpoint(); timer?.invalidate(); timer = nil; recorder?.stop(); recorder = nil
        activeID = nil; isRecording = false; isPaused = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in self.stop(); self.error = "Recording stopped due to an audio error. Review the saved audio before continuing." }
    }
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard !flag else { return }
        Task { @MainActor in self.stop(); self.error = "The recording did not finish normally. Review the saved audio and transcript." }
    }
}
