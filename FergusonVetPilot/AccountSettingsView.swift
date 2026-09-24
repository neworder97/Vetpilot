import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject var account: VetPilotAccount
    @ObservedObject var scribe: ScribeStore
    @Environment(\.dismiss) private var dismiss
    @State private var sharing = false
    @State private var deleteConfirmation = false
    @State private var deleteLocalConfirmation = false
    @State private var notice: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("VetPilot account") {
                    if account.userID != nil {
                        Label(account.email, systemImage: "person.crop.circle.fill")
                        Text("Notes are stored separately for each signed-in account. Signing out switches to this device's guest notes.").font(.caption)
                        Button("Sign out") { Task { await account.signOut() } }.disabled(account.busy || scribe.accountLocked)
                    } else {
                        Text("Create an account or sign in to use the same identity in the app and website.")
                        Button { Task { await account.signIn(provider: "google") } } label: { Label("Continue with Google", systemImage: "person.crop.circle") }
                            .disabled(!account.configured || account.busy || scribe.accountLocked).accessibilityIdentifier("account.google")
                        Button { Task { await account.signIn(provider: "apple") } } label: { Label("Continue with Apple", systemImage: "apple.logo") }
                            .disabled(!account.configured || account.busy || scribe.accountLocked).accessibilityIdentifier("account.apple")
                        Text("Use the same sign-in method on every device. Apple Hide My Email and a Google address can create different accounts.").font(.caption)
                    }
                    if !account.configured { Text("Account and cloud services are not connected in this build. Local recording, editing and PDFs remain available.").foregroundStyle(.secondary).accessibilityIdentifier("account.notConfigured") }
                    if account.busy { ProgressView("Connecting…") }
                }
                Section("Notes & syncing") {
                    Text(scribe.syncStatus).font(.caption)
                    Button("Sync now") { Task { await scribe.sync(account: account) } }.disabled(account.userID == nil || scribe.accountLocked)
                    Button("Download my cloud notes") { Task { await download() } }.disabled(account.userID == nil || !account.configured || account.busy || scribe.accountLocked)
                    Text("Signed-in notes upload after transcription and sync automatically while the app is open. Failed uploads retry; conflicting edits are preserved as a separate copy. Audio stays on its original device. My Clinic and medication settings remain local in this version.").font(.caption)
                    if let notice { Text(notice).font(.caption) }
                }
                Section("Sharing") { Button("Email and text settings") { sharing = true } }
                Section("Privacy & control") {
                    Text("Recording requires everyone's consent. On-device transcription does not send audio to a server. Cloud AI sends only the selected recording or note to your configured service and its AI processor after your confirmation.").font(.caption)
                    Text("Notes and audio are protected on this device and excluded from device backup. Keep PDF exports or explicit cloud copies of records you need. Signing out does not erase local notes.").font(.caption)
                    Button("Erase notes for this local account", role: .destructive) { deleteLocalConfirmation = true }.disabled(scribe.accountLocked)
                    if account.userID != nil { Button("Delete my cloud account", role: .destructive) { deleteConfirmation = true }.disabled(scribe.accountLocked || account.busy) }
                }
            }.navigationTitle("Settings")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(isPresented: $sharing) { ClinicEmailSettings() }
                .confirmationDialog("Erase this account's local notes and recordings?", isPresented: $deleteLocalConfirmation) {
                    Button("Erase local notes", role: .destructive) { do { try scribe.clearLocalAccount(); notice = "Local notes erased." } catch { scribe.error = error.localizedDescription } }
                } message: { Text("This cannot be undone. Cloud copies are not affected.") }
                .confirmationDialog("Delete your cloud account and all synced notes?", isPresented: $deleteConfirmation) {
                    Button("Delete account permanently", role: .destructive) { Task {
                        do { try await account.deleteAccount(); notice = "Cloud account deleted. Local copies remain on this device." }
                        catch { account.error = error.localizedDescription }
                    } }
                } message: { Text("This cannot be undone. Export records you need before continuing.") }
                .alert("Account", isPresented: Binding(get: { account.error != nil }, set: { if !$0 { account.error = nil } })) {
                    Button("OK") { account.error = nil }
                } message: { Text(account.error ?? "") }
        }
    }
    private func download() async {
        scribe.busy = true; defer { scribe.busy = false }
        do {
            let rows = try await ScribeCloud.download(account: account)
            var conflicts = 0
            for row in rows {
                var remote = try row.payload.validated(); remote.recordingFiles = []
                guard row.id == remote.id else { throw ScribeError.invalid("Cloud encounter identity mismatch.") }
                if let local = scribe.encounter(row.id) {
                    if row.version <= local.syncVersion { continue }
                    if local.syncedAt == nil || local.updatedAt > local.syncedAt! {
                        var preserved = local; preserved.id = UUID(); preserved.title += " (local copy)"; preserved.syncVersion = 0; preserved.syncedAt = nil
                        try scribe.save(preserved); conflicts += 1
                    } else { remote.recordingFiles = local.recordingFiles }
                }
                remote.syncVersion = row.version; remote.syncedAt = Date(); try scribe.save(remote)
            }
            notice = "Downloaded \(rows.count) cloud records. Preserved \(conflicts) conflicting local copies."
        } catch { account.error = error.localizedDescription }
    }
}
