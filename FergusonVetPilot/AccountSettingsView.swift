import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject var account: VetPilotAccount
    @Environment(\.dismiss) private var dismiss
    @State private var loginEmail = ""
    @State private var password = ""
    @State private var createAccount = false
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
                        Text("Your My Clinic and Cytology collections stay separate for each account.").font(.caption)
                        Button("Sign out") { Task { await account.signOut() } }.disabled(account.busy)
                    } else {
                        Text("Create an account or sign in to use the same identity in the app and website.")
                        Picker("Account", selection: $createAccount) {
                            Text("Sign in").tag(false)
                            Text("Create account").tag(true)
                        }.pickerStyle(.segmented)
                        TextField("Email", text: $loginEmail).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Password", text: $password).textContentType(createAccount ? .newPassword : .password)
                        if createAccount { Text("Use at least 12 characters.").font(.caption) }
                        Button(createAccount ? "Create account" : "Sign in") {
                            let submittedPassword = password
                            let submittedEmail = loginEmail
                            let creating = createAccount
                            Task {
                                await account.authenticate(email: submittedEmail, password: submittedPassword, create: creating)
                                if account.userID != nil { password = "" }
                            }
                        }.disabled(!account.configured || account.busy).accessibilityIdentifier("account.email.submit")
                        Text("Use the same email and password in the app and website.").font(.caption)
                        if let message = account.notice { Text(message).font(.caption) }
                    }
                    if !account.configured { Text("Account and cloud services are not connected in this build. Guest reference tools remain available.").foregroundStyle(.secondary).accessibilityIdentifier("account.notConfigured") }
                    if account.busy { ProgressView("Connecting…") }
                }
                Section("Syncing") {
                    Text("My Clinic and Cytology images, labels and notes sync every minute while open and online, and when you return to the app. Guest collections stay on this device.")
                }
                Section("Remove old Scribe data") {
                    Text("Scribe has been replaced. Delete its old notes and recordings from this device and its cloud notes from your signed-in account.")
                    Button("Delete old Scribe records", role: .destructive) { deleteLocalConfirmation = true }
                    if let notice { Text(notice) }
                }
            }.navigationTitle("Settings")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Delete old Scribe notes and recordings?", isPresented: $deleteLocalConfirmation) {
                    Button("Delete Scribe records", role: .destructive) { Task {
                        do {
                            if let id = account.userID { _ = try await account.request(path: "rest/v1/scribe_encounters?user_id=eq." + id.uuidString.lowercased(), method: "DELETE") }
                            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("VetPilot/Scribe")
                            if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
                            notice = "Scribe records deleted. My Clinic and Cytology were not changed."
                        } catch { account.error = error.localizedDescription }
                    } }
                } message: { Text("This cannot be undone. My Clinic and Cytology are not affected.") }
                .alert("Account", isPresented: Binding(get: { account.error != nil }, set: { if !$0 { account.error = nil } })) {
                    Button("OK") { account.error = nil }
                } message: { Text(account.error ?? "") }
        }
    }
}
