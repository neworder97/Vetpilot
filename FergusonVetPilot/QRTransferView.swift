import SwiftUI
import AVFoundation
import VisionKit

struct QRTransferView: View {
    @ObservedObject var store: ClinicStore
    @EnvironmentObject private var account: VetPilotAccount
    let collection: QRCollection
    var receiving = false
    @Environment(\.dismiss) private var dismiss
    @State private var mode = "Share"
    @State private var selected = Set<UUID>()
    @State private var busy = false
    @State private var error: String?
    @State private var notice: String?
    @State private var created: QRSharedTransfer?
    @State private var qrImage: UIImage?
    @State private var link = ""
    @State private var preview: ClinicPackage?
    @State private var previewOwner: UUID?
    @State private var links: [QRSharedTransfer] = []
    @State private var scanning = false
    @State private var sharing: ClinicShare?
    private var selectedItems: [ClinicProtocol] { store.items.filter { selected.contains($0.id) } }
    private var signedIn: Bool { account.userID != nil && store.signedInForSync }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Share selected records and photos using a temporary QR link. Internet and a VetPilot account are required.")
                    Text("Anyone with the code or link who signs in can view the shared copies until it expires. Share only with intended recipients.").font(.caption).foregroundStyle(.secondary)
                    Picker("QR action", selection: $mode) { ForEach(["Share", "Receive", "Manage"], id: \.self) { Text($0) } }.pickerStyle(.segmented).disabled(busy)
                    if !signedIn { Text("Sign in through Account & settings to use QR transfers.").foregroundStyle(.orange) }
                    if busy { ProgressView("Working…") }
                    if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("qr.error") }
                    if let notice { Text(notice).accessibilityIdentifier("qr.notice") }
                }
                if mode == "Share" { shareContent }
                if mode == "Receive" { receiveContent }
                if mode == "Manage" { manageContent }
            }
            .navigationTitle("\(collection.title) QR sharing").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.disabled(busy) } }
            .interactiveDismissDisabled(busy)
            .onAppear { mode = receiving ? "Receive" : "Share" }
            .onChange(of: mode) { _, value in error = nil; notice = nil; if value == "Manage" && signedIn { loadLinks() } }
            .sheet(isPresented: $scanning) {
                NavigationStack {
                    QRScannerView(onRead: { value in scanning = false; link = value; receive() }, onError: { value in scanning = false; error = value })
                        .navigationTitle("Scan QR Code").toolbar { Button("Cancel") { scanning = false } }
                }
            }
            .sheet(item: $sharing) { ClinicShareSheet(urls: $0.urls) }
        }
    }
    @ViewBuilder private var shareContent: some View {
        if let created {
            Section("QR code") {
                if let qrImage { Image(uiImage: qrImage).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 320).accessibilityLabel("VetPilot transfer QR code") }
                Text("\(created.itemCount) items • Expires \(created.expirationText)")
                if let url = created.url {
                    Text(url).font(.caption).textSelection(.enabled)
                    Button("Copy link") { UIPasteboard.general.string = url; notice = "Link copied." }
                    Button("Share QR image and link") { shareImage(url) }
                }
                Button("Revoke link", role: .destructive) { run {
                    try await QRTransferService.revoke(account: account, collection: collection, id: created.id)
                    self.created = nil; qrImage = nil; notice = "Link revoked. Existing imported copies are unaffected."
                } }.disabled(busy || !signedIn)
            }
        } else {
            Section("Select items") {
                HStack { Button("Select all") { selected = Set(store.items.map(\.id)) }; Spacer(); Button("Clear") { selected.removeAll() } }.buttonStyle(.borderless).disabled(busy)
                Text("\(selectedItems.count) of \(store.items.count) selected").accessibilityIdentifier("qr.selection.count")
                ForEach(store.items) { item in
                    Toggle(isOn: Binding(get: { selected.contains(item.id) }, set: { if $0 { selected.insert(item.id) } else { selected.remove(item.id) } })) {
                        VStack(alignment: .leading) { Text(item.title); Text("\(item.photos.count) photos").font(.caption) }
                    }.disabled(busy).accessibilityIdentifier("qr.select.\(item.title)")
                }
            }
            Section {
                Button("Create QR Code") { run {
                    let share = try await QRTransferService.create(account: account, collection: collection, items: selectedItems)
                    created = share; qrImage = try QRSharingLink.image(share.url!)
                } }.disabled(busy || !signedIn || selectedItems.isEmpty).accessibilityIdentifier("qr.create")
                Text("Links expire after 24 hours. Up to 15 MB per transfer; select fewer items if needed.").font(.caption)
            }
        }
    }
    @ViewBuilder private var receiveContent: some View {
        if let preview {
            Section("Review before importing") {
                Text("\(preview.items.count) items will be added to \(collection.title) as separate editable copies. Existing items will not be replaced.")
                Text("Review sender-provided content before use.").foregroundStyle(.orange)
            }
            ForEach(preview.items) { item in
                Section(item.title) {
                    Text("\(item.category) • \(item.photos.count) photos")
                    if !item.summary.isEmpty { Text(item.summary) }
                    ForEach(item.steps) { Text($0.text) }
                    ForEach(item.equipment) { Text("\($0.name) • \($0.quantity) • \($0.size) • \($0.location)") }
                    if !item.notes.isEmpty { Text(item.notes) }
                    ForEach(item.photos) { photo in
                        if let image = UIImage(data: photo.jpeg) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240) }
                        Text(photo.caption)
                    }
                }
            }
            Section {
                Button("Import copies into \(collection.title)") {
                    guard signedIn, account.userID == previewOwner else { error = "Account changed. Reopen QR sharing."; return }
                    do { try store.importCopies(preview); self.preview = nil; notice = "Imported \(preview.items.count) copies into \(collection.title)." }
                    catch { self.error = error.localizedDescription }
                }.disabled(busy || !signedIn).accessibilityIdentifier("qr.import.confirm")
                Button("Cancel preview") { self.preview = nil }
            }
        } else {
            Section("Receive") {
                Button("Start camera") { startScanner() }.disabled(busy || !signedIn)
                TextField("Paste a VetPilot sharing link", text: $link, axis: .vertical).textInputAutocapitalization(.never).autocorrectionDisabled().disabled(busy).accessibilityIdentifier("qr.link")
                Button("Preview shared items") { receive() }.disabled(busy || !signedIn || link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("qr.preview")
                Text("You can also scan the code with your phone's Camera app to open the website preview.").font(.caption)
            }
        }
    }
    @ViewBuilder private var manageContent: some View {
        Section("Active links") {
            Button("Refresh links") { loadLinks() }.disabled(busy || !signedIn)
            if links.isEmpty && !busy { Text("No active QR links.") }
            ForEach(links) { item in
                VStack(alignment: .leading) {
                    Text(item.title).font(.headline); Text("\(item.itemCount) items • Expires \(item.expirationText)").font(.caption)
                    Button("Revoke link", role: .destructive) { run {
                        try await QRTransferService.revoke(account: account, collection: collection, id: item.id)
                        links.removeAll { $0.id == item.id }; if created?.id == item.id { created = nil; qrImage = nil }; notice = "Link revoked."
                    } }.disabled(busy || !signedIn)
                }
            }
        }
    }
    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }; busy = true; error = nil; notice = nil
        Task { defer { busy = false }; do { try await operation() } catch { self.error = error.localizedDescription } }
    }
    private func receive() { run { preview = nil; previewOwner = account.userID; preview = try await QRTransferService.receive(account: account, collection: collection, link: link) } }
    private func loadLinks() { run { links = try await QRTransferService.list(account: account, collection: collection) } }
    private func startScanner() { run {
        guard DataScannerViewController.isSupported else { throw ClinicFileError.invalid("Camera scanning unavailable on this device. Paste the sharing link instead.") }
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        guard allowed, DataScannerViewController.isAvailable else { throw ClinicFileError.invalid("Allow camera access in Settings, or paste the sharing link.") }; scanning = true
    } }
    private func shareImage(_ link: String) {
        do {
            guard let data = qrImage?.pngData(), let url = URL(string: link) else { return }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("VetPilotQR-\(UUID().uuidString)"); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let image = folder.appendingPathComponent("VetPilot-sharing-QR.png"); try data.write(to: image, options: .atomic); sharing = ClinicShare(urls: [image, url])
        } catch { self.error = error.localizedDescription }
    }
}
