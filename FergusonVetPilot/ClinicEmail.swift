import SwiftUI
import MessageUI

struct ClinicEmailDraft: Identifiable {
    let id = UUID()
    let data: Data
    let filename: String
    let mimeType: String
    let recipients: [String]
    let subject: String

    static func recipient(_ value: String) throws -> [String] {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return [] }
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."),
              !parts[1].hasPrefix("."), !parts[1].hasSuffix("."),
              !value.contains(where: { $0.isWhitespace || $0 == "," || $0 == ";" }) else {
            throw ClinicFileError.invalid("Enter one email address, or leave the default recipient blank.")
        }
        return [value]
    }

    static func make(url: URL, recipient: String) throws -> ClinicEmailDraft {
        ClinicEmailDraft(data: try Data(contentsOf: url), filename: url.lastPathComponent,
                         mimeType: url.pathExtension.lowercased() == "pdf" ? "application/pdf" : "application/vnd.vetpilot.protocol+json",
                         recipients: try Self.recipient(recipient), subject: "VetPilot — My Clinic protocols")
    }
}

struct ClinicEmailButton: View {
    let items: [ClinicProtocol]
    let pdf: Bool
    @AppStorage("clinic.email.recipient") private var recipient = ""
    @State private var draft: ClinicEmailDraft?
    @State private var fallback: ClinicShare?
    @State private var unavailable = false
    @State private var preparedURL: URL?
    @State private var error: String?

    var body: some View {
        Button {
            do {
                let url = try ClinicTransfer.export(items, pdf: pdf)
                if MFMailComposeViewController.canSendMail() {
                    draft = try ClinicEmailDraft.make(url: url, recipient: recipient)
                } else { preparedURL = url; unavailable = true }
            } catch { self.error = error.localizedDescription }
        } label: { Label(pdf ? "Email PDF" : "Email editable .vetpilot file", systemImage: "envelope") }
        .accessibilityIdentifier(pdf ? "clinic.email.pdf" : "clinic.email.file")
        .sheet(item: $draft) { value in
            ClinicMailComposer(draft: value) { message in draft = nil; error = message }
        }
        .sheet(item: $fallback) { ClinicShareSheet(urls: $0.urls) }
        .alert("Email setup needed", isPresented: $unavailable) {
            Button("Choose email app") {
                if let preparedURL { fallback = ClinicShare(urls: [preparedURL]) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To compose email inside VetPilot, configure an account in Apple's Mail app. You can also choose Gmail, Outlook or another installed app from the share sheet. The export file will be attached; enter the recipient there.")
        }
        .alert("Email export", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
}

struct ClinicMailComposer: UIViewControllerRepresentable {
    let draft: ClinicEmailDraft
    let completed: (String?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completed: completed) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(draft.recipients)
        controller.setSubject(draft.subject)
        controller.setMessageBody("Please find the attached VetPilot My Clinic export. Review clinical content before use. Open the .vetpilot file in VetPilot to import an editable copy; PDFs are for reading. Thank you.", isHTML: false)
        controller.addAttachmentData(draft.data, mimeType: draft.mimeType, fileName: draft.filename)
        return controller
    }
    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let completed: (String?) -> Void
        init(completed: @escaping (String?) -> Void) { self.completed = completed }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            completed(error?.localizedDescription ?? (result == .failed ? "Mail could not send this export. Please try again." : nil))
        }
    }
}

struct ClinicEmailSettings: View {
    @AppStorage("clinic.email.recipient") private var recipient = ""
    @AppStorage("clinic.text.recipient") private var phone = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var canSend = MFMailComposeViewController.canSendMail()
    private var recipientError: String? {
        do { _ = try ClinicEmailDraft.recipient(recipient); return nil }
        catch { return error.localizedDescription }
    }
    private var phoneError: String? {
        do { _ = try ClinicTextDraft.recipient(phone); return nil }
        catch { return error.localizedDescription }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Email account") {
                    Label(canSend ? "Apple Mail is ready" : "Apple Mail is not configured", systemImage: canSend ? "checkmark.circle" : "envelope.badge")
                    Text("VetPilot uses the accounts configured in Apple's Mail app. Add your account in Mail, then return here. You can select the sending account in the email draft. VetPilot does not store your email password.")
                    Text("Prefer Gmail or Outlook? Use Share and choose your installed email app. The export is attached to the draft.").font(.footnote)
                }
                Section("Default recipient (optional)") {
                    TextField("name@example.com", text: $recipient)
                        .keyboardType(.emailAddress).textContentType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("clinic.email.recipient")
                    Text("Used by Email PDF and Email editable file when Apple Mail is configured. You can change it before sending. Leave blank to choose a recipient each time.").font(.footnote)
                    if let recipientError { Text(recipientError).foregroundStyle(.red) }
                }
                Section("Text messaging") {
                    Text("VetPilot uses Messages on your iPhone. Configure your phone number or Apple Account in Messages. You choose the recipient and tap Send in the draft.")
                    TextField("Default recipient phone (optional)", text: $phone)
                        .keyboardType(.phonePad).textContentType(.telephoneNumber)
                        .accessibilityIdentifier("clinic.text.recipient")
                    if let phoneError { Text(phoneError).foregroundStyle(.red) }
                    Text("Use a country code when needed. Leave blank to choose each time. Files require iMessage or supported attachment messaging, not plain SMS; size limits may apply.").font(.footnote)
                }
                Section("Export destination") {
                    Text("Email export attaches a copy to an email draft. Review it and tap Send yourself. Share lets you choose Mail, AirDrop or Save to Files; files are not automatically saved to Downloads.")
                }
            }
            .navigationTitle("Sharing settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onChange(of: scenePhase) { _, phase in if phase == .active { canSend = MFMailComposeViewController.canSendMail() } }
        }
    }
}

struct ClinicTextDraft: Identifiable {
    let id = UUID()
    let url: URL
    let recipients: [String]
    static func recipient(_ value: String) throws -> [String] {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return [] }
        let allowed = CharacterSet(charactersIn: "+0123456789 ()-.")
        let normalized = value.filter { $0 == "+" || $0.isNumber }
        let digits = normalized.filter { $0.isNumber }
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }), (7...15).contains(digits.count),
              normalized.filter({ $0 == "+" }).count <= 1,
              !normalized.contains("+") || normalized.hasPrefix("+") else {
            throw ClinicFileError.invalid("Enter one phone number, including country code when needed, or leave it blank.")
        }
        return [normalized]
    }
}

struct ClinicTextButton: View {
    let items: [ClinicProtocol]
    let pdf: Bool
    @AppStorage("clinic.text.recipient") private var recipient = ""
    @State private var draft: ClinicTextDraft?
    @State private var fallback: ClinicShare?
    @State private var preparedURL: URL?
    @State private var unavailable = false
    @State private var error: String?
    var body: some View {
        Button {
            do {
                let url = try ClinicTransfer.export(items, pdf: pdf)
                preparedURL = url
                if MFMessageComposeViewController.canSendText() && MFMessageComposeViewController.canSendAttachments() {
                    draft = ClinicTextDraft(url: url, recipients: try ClinicTextDraft.recipient(recipient))
                } else { unavailable = true }
            } catch { self.error = error.localizedDescription }
        } label: { Label(pdf ? "Text PDF" : "Text editable .vetpilot file", systemImage: "message") }
        .accessibilityIdentifier(pdf ? "clinic.text.pdf" : "clinic.text.file")
        .sheet(item: $draft) { value in
            ClinicMessageComposer(draft: value) { message in draft = nil; error = message }
        }
        .sheet(item: $fallback) { ClinicShareSheet(urls: $0.urls) }
        .alert("Messages setup needed", isPresented: $unavailable) {
            Button("Choose sharing app") { if let preparedURL { fallback = ClinicShare(urls: [preparedURL]) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("File messaging is unavailable on this device. Configure Messages on your iPhone, or choose another sharing app. Attachments need iMessage or a supported messaging service; ordinary SMS does not carry files. File size limits may apply.")
        }
        .alert("Text export", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Choose sharing app") { if let preparedURL { fallback = ClinicShare(urls: [preparedURL]) } }
            Button("Cancel", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
}

struct ClinicMessageComposer: UIViewControllerRepresentable {
    let draft: ClinicTextDraft
    let completed: (String?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completed: completed) }
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = draft.recipients
        controller.body = "VetPilot My Clinic export — review before clinical use. Open the .vetpilot file in VetPilot to import an editable copy."
        if !controller.addAttachmentURL(draft.url, withAlternateFilename: draft.url.lastPathComponent) {
            controller.disableUserAttachments()
            DispatchQueue.main.async { completed("Messages could not attach this file. Use the share sheet to choose another app or send a PDF instead.") }
        }
        return controller
    }
    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}
    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let completed: (String?) -> Void
        init(completed: @escaping (String?) -> Void) { self.completed = completed }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            completed(result == .failed ? "Messages could not send this export. Try another sharing app." : nil)
        }
    }
}
