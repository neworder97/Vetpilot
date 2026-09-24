import SwiftUI
import AVFoundation
import Translation

struct ScribeView: View {
    @ObservedObject var store: ScribeStore
    @ObservedObject var account: VetPilotAccount
    @State private var creating = false
    @State private var search = ""
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Record once. Review a separate note for each patient.").font(.headline)
                    Text("Only record with everyone's consent. Drafts can contain errors; review names, clinical terms, numbers and patient attribution.").font(.caption)
                    Button("New encounter", systemImage: "plus") { creating = true }.accessibilityIdentifier("scribe.new")
                }
                Section("Saved encounters") {
                    ForEach(store.encounters.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.patients.contains { $0.name.localizedCaseInsensitiveContains(search) } }) { encounter in
                        NavigationLink {
                            ScribeEncounterView(store: store, account: account, value: encounter)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(encounter.title).font(.headline)
                                Text(encounter.patients.map(\.name).joined(separator: ", ")).font(.subheadline)
                                Text(encounter.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                                Text(encounter.notes.allSatisfy { $0.finalizedAt != nil } ? "Reviewed notes" : "Draft — needs review").font(.caption).foregroundStyle(.secondary)
                            }
                        }.accessibilityIdentifier("scribe.encounter.\(encounter.id)")
                    }
                }
                if store.encounters.isEmpty { Text("Your recordings and notes stay on this device unless you choose cloud processing or upload. Signed-in accounts have separate note storage.").font(.caption) }
            }
            .navigationTitle("Scribe")
            .searchable(text: $search, prompt: "Patient or encounter")
            .sheet(isPresented: $creating) { ScribeNewEncounter(store: store) }
        }
    }
}

private struct ScribeNewEncounter: View {
    @ObservedObject var store: ScribeStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var patients = [ScribePatient(name: "")]
    @State private var historyOnly = true
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                TextField("Visit title (optional)", text: $title)
                Toggle("History only", isOn: $historyOnly)
                Text(historyOnly ? "Only history is drafted. Exam, assessment and plan stay blank for clinician entry." : "SOAP drafting uses only information actually stated. It must not invent examination findings or a treatment plan.").font(.caption)
                ForEach($patients) { $patient in
                    Section("Patient") {
                        TextField("Pet name / unique spoken name", text: $patient.name).accessibilityIdentifier("scribe.patient.name")
                        Picker("Species", selection: $patient.species) { ForEach(["Dog", "Cat", "Other"], id: \.self) { Text($0) } }
                        TextField("Patient ID (optional)", text: $patient.reference)
                        TextField("Other spoken names, comma separated", text: $patient.aliases)
                        if patients.count > 1 { Button("Remove patient", role: .destructive) { patients.removeAll { $0.id == patient.id } } }
                    }
                }
                if patients.count < 8 { Button("Add another patient") { patients.append(ScribePatient(name: "")) }.accessibilityIdentifier("scribe.patient.add") }
                if let error { Text(error).foregroundStyle(.red) }
                Button("Create encounter") {
                    do { try store.save(ScribeEncounter.create(title: title, patients: patients, historyOnly: historyOnly)); dismiss() }
                    catch { self.error = error.localizedDescription }
                }.accessibilityIdentifier("scribe.create")
            }.navigationTitle("New encounter")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }.accessibilityIdentifier("scribe.keyboard.done") }
                }
        }
    }
}

struct ScribeEncounterView: View {
    @ObservedObject var store: ScribeStore
    @ObservedObject var account: VetPilotAccount
    @State var value: ScribeEncounter
    @Environment(\.dismiss) private var dismiss
    @State private var consent = false
    @State private var cloud = false
    @State private var cloudConsent = false
    @State private var replacementAction: String?
    @State private var confirmDelete = false
    @State private var confirmAudioDelete = false
    @State private var uploadConfirm = false
    @State private var playback: AVAudioPlayer?
    private var locked: Bool { store.busy || store.hasActiveRecording }
    var body: some View {
        Form {
            Section("Patients") {
                ForEach(value.patients) { patient in Text("\(patient.name) — \(patient.species)") }
                Text("Say the pet's name before discussing that patient. Statements involving multiple pets or unclear ownership need manual review.").font(.caption)
            }
            Section("Recording") {
                Toggle("Everyone present has consented to recording", isOn: $consent).disabled(store.hasActiveRecording)
                    .accessibilityIdentifier("scribe.consent")
                Picker("Spoken language", selection: $value.locale) {
                    ForEach(["en-US", "es-ES", "fr-FR", "de-DE", "pt-BR", "it-IT", "zh-CN", "ja-JP", "ar-SA"], id: \.self) { Text(Locale.current.localizedString(forIdentifier: $0) ?? $0) }
                }.disabled(locked)
                if store.activeID == value.id {
                    Text(store.isRecording ? "Recording continues across tabs" : "Recording paused").foregroundStyle(store.isRecording ? .red : .orange)
                    HStack {
                        Button(store.isRecording ? "Pause" : "Resume") { store.isRecording ? store.pause() : store.resume() }.buttonStyle(.bordered)
                        Button("Stop") { store.stop() }.buttonStyle(.borderedProminent).tint(.red)
                    }
                } else {
                    Button("Start recording", systemImage: "mic.fill") { playback?.stop(); Task { await store.start(value.id, consent: consent) } }
                        .disabled(!consent || locked).accessibilityIdentifier("scribe.record")
                }
                Text("Recorded: \(Int(value.recordedSeconds)) seconds · \(value.recordingFiles.count) audio file(s)").font(.caption)
                ForEach(Array(value.recordingFiles.enumerated()), id: \.element) { index, filename in
                    Button("Listen to recording \(index + 1)", systemImage: "play.circle") {
                        do { playback?.stop(); try AVAudioSession.sharedInstance().setCategory(.playback); try AVAudioSession.sharedInstance().setActive(true); playback = try AVAudioPlayer(contentsOf: store.audioURL(filename)); playback?.play() }
                        catch { store.error = error.localizedDescription }
                    }.disabled(locked)
                }
                if playback != nil { Button("Stop playback") { playback?.stop(); playback = nil; try? AVAudioSession.sharedInstance().setActive(false) } }
            }
            Section("Transcribe & create notes") {
                Toggle("Use cloud AI", isOn: $cloud).disabled(!account.configured || account.userID == nil || locked)
                if cloud {
                    Toggle("I consent to sending this recording and patient details for cloud AI processing", isOn: $cloudConsent).disabled(locked)
                } else {
                    Text("On-device mode transcribes supported languages and copies explicit patient history into editable drafts. It does not generate a clinical assessment. Cloud AI requires a connected service and sign-in.").font(.caption)
                }
                Button("Transcribe & Create Notes") { requestProcessing("audio") }
                    .disabled(locked || value.recordingFiles.isEmpty || (cloud && !cloudConsent)).accessibilityIdentifier("scribe.transcribe")
                if store.busy { ProgressView(store.progress) }
            }
            Section("Transcript — editable") {
                TextEditor(text: $value.transcript).frame(minHeight: 140).disabled(locked).accessibilityIdentifier("scribe.transcript")
                Button("Create notes from text") { requestProcessing("text") }
                    .disabled(locked || value.transcript.isEmpty || (cloud && !cloudConsent)).accessibilityIdentifier("scribe.draft")
                Text("Creating notes replaces existing drafts. The original audio is retained until you delete it.").font(.caption)
            }
            Section("Patient notes") {
                ForEach(value.patients) { patient in
                    NavigationLink(patient.name) { ScribeNoteEditor(store: store, account: account, encounterID: value.id, patientID: patient.id) }
                        .disabled(locked).accessibilityIdentifier("scribe.note.\(patient.name)")
                }
                Text(value.processingMethod).font(.caption)
            }
            if !value.unassigned.isEmpty {
                Section("Unassigned — confirm the patient") {
                    TextEditor(text: $value.unassigned).frame(minHeight: 120).disabled(locked)
                    Menu("Move these statements to patient's history") {
                        ForEach(value.patients) { patient in Button(patient.name) { do { try value.assignUnresolved(to: patient.id) } catch { store.error = error.localizedDescription } } }
                    }.disabled(locked)
                    Text("Edit this area first if statements need to go to different patients. Review the destination note after moving them.").font(.caption)
                }
            }
            if !value.reviewFlags.isEmpty { Section("Review reminders") { ForEach(Array(value.reviewFlags.enumerated()), id: \.offset) { _, text in Text(text).font(.caption) } } }
            Section("Cloud copy") {
                Button("Upload this encounter") { uploadConfirm = true }.disabled(locked || account.userID == nil || !account.configured)
                if let date = value.syncedAt { Text("Last uploaded: \(date.formatted())").font(.caption) }
                Text("Uploads notes, patient details and the transcript to your account. Audio stays on this device. Future website access will use the same account.").font(.caption)
            }
            Section {
                Button("Delete audio only", role: .destructive) { confirmAudioDelete = true }.disabled(locked || value.recordingFiles.isEmpty)
                Button("Delete local encounter", role: .destructive) { confirmDelete = true }.disabled(locked)
            }
        }.navigationTitle(value.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }.accessibilityIdentifier("scribe.keyboard.done") } }
            .onChange(of: value) { old, new in
                guard old != new else { return }
                do { try store.save(new) } catch { store.error = error.localizedDescription }
            }
            .onChange(of: store.encounters) { _, _ in if let current = store.encounter(value.id), current != value { value = current } }
            .onDisappear { playback?.stop(); playback = nil }
            .confirmationDialog("Replace the current patient drafts?", isPresented: Binding(get: { replacementAction != nil }, set: { if !$0 { replacementAction = nil } })) {
                Button("Replace drafts", role: .destructive) { let action = replacementAction; replacementAction = nil; runProcessing(action ?? "text") }
            } message: { Text("This will clear prior note edits, review status and translations. Export anything you need to keep first.") }
            .confirmationDialog("Delete this local encounter and its audio?", isPresented: $confirmDelete) {
                Button("Delete local encounter", role: .destructive) { do { try store.delete(value.id); dismiss() } catch { store.error = error.localizedDescription } }
            } message: { Text("Uploaded cloud copies are not deleted by this action.") }
            .confirmationDialog("Permanently delete local audio?", isPresented: $confirmAudioDelete) {
                Button("Delete audio", role: .destructive) { do { try store.deleteAudio(value.id) } catch { store.error = error.localizedDescription } }
            }
            .confirmationDialog("Upload patient details, transcript and notes to your account?", isPresented: $uploadConfirm) {
                Button("Upload") { Task { await upload() } }
            }
    }
    private func requestProcessing(_ action: String) {
        if value.notes.contains(where: \.hasContent) { replacementAction = action } else { runProcessing(action) }
    }
    private func runProcessing(_ action: String) {
        playback?.stop()
        Task { if action == "audio" { await store.transcribe(value.id, cloud: cloud, account: account) }
               else { await store.draftText(value.id, cloud: cloud, account: account) } }
    }
    private func upload() async {
        store.busy = true; defer { store.busy = false }
        do { let version = try await ScribeCloud.upload(value, account: account); value.syncVersion = version; value.syncedAt = Date(); try store.save(value) }
        catch { store.error = error.localizedDescription }
    }
}

struct ScribeNoteEditor: View {
    @ObservedObject var store: ScribeStore
    @ObservedObject var account: VetPilotAccount
    let encounterID: UUID
    let patientID: UUID
    @State private var reviewer = ""
    @State private var share: ClinicShare?
    @State private var language = "Spanish"
    @State private var cloudTranslationConsent = false
    private var encounter: ScribeEncounter? { store.encounter(encounterID) }
    private var note: SOAPNote? { encounter?.notes.first { $0.patientID == patientID } }
    private var patient: ScribePatient? { encounter?.patients.first { $0.id == patientID } }
    private func field(_ key: WritableKeyPath<SOAPNote, String>) -> Binding<String> {
        Binding(get: { note?[keyPath: key] ?? "" }, set: { text in update { $0[keyPath: key] = text; $0.edited() } })
    }
    private func update(_ change: (inout SOAPNote) -> Void) {
        guard var encounter, let index = encounter.notes.firstIndex(where: { $0.patientID == patientID }) else { return }
        change(&encounter.notes[index]); encounter.updatedAt = Date()
        do { try store.save(encounter) } catch { store.error = error.localizedDescription }
    }
    var body: some View {
        Form {
            Section {
                Text(note?.finalizedAt == nil ? "DRAFT — needs clinician review" : "Reviewed by \(note?.reviewer ?? "")").font(.headline).accessibilityIdentifier("scribe.note.status")
                Text("Check this patient's name, history, negations, numbers and units against the transcript. Editing a note clears its review status and translation.").font(.caption)
            }
            Section("Subjective / history") { TextEditor(text: field(\.subjective)).frame(minHeight: 150).accessibilityIdentifier("scribe.note.subjective") }
            Section("Objective — clinician-supplied findings") { TextEditor(text: field(\.objective)).frame(minHeight: 100) }
            Section("Assessment — clinician-supplied") { TextEditor(text: field(\.assessment)).frame(minHeight: 100) }
            Section("Plan — clinician-supplied") { TextEditor(text: field(\.plan)).frame(minHeight: 100) }
            Section("Review & export") {
                TextField("Reviewing clinician", text: $reviewer).accessibilityIdentifier("scribe.reviewer")
                Button("Finalize reviewed note") {
                    guard encounter?.unassigned.isEmpty == true else { store.error = "Resolve the unassigned statements before finalizing patient notes."; return }
                    update { item in do { try item.finalize(reviewer: reviewer) } catch { store.error = error.localizedDescription } }
                }.disabled(reviewer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || note?.hasContent != true).accessibilityIdentifier("scribe.finalize")
                Button("Export / Print PDF", systemImage: "square.and.arrow.up") { export(translated: false) }.accessibilityIdentifier("scribe.pdf")
                Text("Draft PDFs are visibly marked as unreviewed. Choose Print from the share sheet to use AirPrint.").font(.caption)
            }
            if let note, note.finalizedAt != nil {
                Section("Translation") {
                    Picker("Language", selection: $language) { ForEach(Self.languages.map(\.0), id: \.self) { Text($0) } }
                    if #available(iOS 18.0, *) {
                        ScribeDeviceTranslation(text: note.plainText, source: encounter?.locale ?? "en-US", target: Self.languages.first { $0.0 == language }?.1 ?? "es") { text in
                            update { $0.translation = NoteTranslation(language: language, text: text, sourceText: note.plainText) }
                        }
                    } else { Text("On-device translation requires iOS 18 or later. Cloud translation is available when configured.").font(.caption) }
                    Toggle("Permit sending this note for cloud translation", isOn: $cloudTranslationConsent)
                    Button("Translate with cloud AI") { Task {
                        store.busy = true; defer { store.busy = false }
                        do { let translation = try await ScribeCloud.translation(note, language: language, account: account); update { $0.translation = translation } }
                        catch { store.error = error.localizedDescription }
                    } }.disabled(!cloudTranslationConsent || !account.configured || account.userID == nil || store.busy)
                    if let translation = note.translation {
                        Text("\(translation.language) — translation draft").font(.headline)
                        TextEditor(text: Binding(get: { self.note?.translation?.text ?? "" }, set: { text in update { $0.translation?.text = text; $0.translation?.reviewed = false } })).frame(minHeight: 200)
                        Toggle("I reviewed this translation against the original", isOn: Binding(get: { self.note?.translation?.reviewed ?? false }, set: { reviewed in update { $0.translation?.reviewed = reviewed } }))
                        Button("Export translated PDF") { export(translated: true) }.disabled(!translation.reviewed)
                    }
                }
            }
        }.navigationTitle(patient?.name ?? "Patient note").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }.accessibilityIdentifier("scribe.keyboard.done") } }
            .disabled(store.busy)
            .sheet(item: $share) { ClinicShareSheet(urls: $0.urls) }
    }
    static let languages = [("Spanish", "es"), ("English", "en"), ("French", "fr"), ("German", "de"), ("Portuguese", "pt"), ("Italian", "it"), ("Chinese", "zh"), ("Japanese", "ja"), ("Korean", "ko"), ("Arabic", "ar"), ("Russian", "ru"), ("Hindi", "hi")]
    private func export(translated: Bool) {
        do { guard let encounter else { return }; share = ClinicShare(urls: [try ScribePDF.export(encounter: encounter, patientID: patientID, translated: translated)]) }
        catch { store.error = error.localizedDescription }
    }
}

@available(iOS 18.0, *)
private struct ScribeDeviceTranslation: View {
    let text: String
    let source: String
    let target: String
    let completed: (String) -> Void
    @State private var configuration: TranslationSession.Configuration?
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading) {
            Button(busy ? "Translating…" : "Translate on device") {
                busy = true; error = nil
                if configuration == nil { configuration = .init(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target)) }
                else { configuration?.invalidate() }
            }.disabled(busy)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .onChange(of: target) { _, _ in configuration = nil }
        .onChange(of: text) { _, _ in configuration = nil }
        .translationTask(configuration) { session in
            do { let response = try await session.translate(text); completed(response.targetText) }
            catch { self.error = "Translation unavailable for this language or device. Download the requested language support or use configured cloud translation." }
            busy = false
        }
    }
}
