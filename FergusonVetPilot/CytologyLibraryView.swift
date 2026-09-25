import SwiftUI
import PhotosUI

struct CytologyLibraryView: View {
    @ObservedObject var store: ClinicStore
    var onSync: (() -> Void)? = nil
    var onAccount: (() -> Void)? = nil
    @State private var query = ""
    @State private var category = "All"
    @State private var favorites = false
    @State private var editing: ClinicProtocol?
    static let categories = ["Ear cytology", "Lymph node", "Neoplasia / cancer", "Skin / mass", "Blood", "Urine", "Body fluid", "Normal cells", "Other"]
    var filtered: [ClinicProtocol] {
        store.items.filter { $0.matches(query) && (category == "All" || $0.category == category) && (!favorites || $0.favorite) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your microscopy learning collection").font(.headline)
                    Text("Save images, label what you see, and build a personal reference. Labels are your observations, not an automated diagnosis.").font(.subheadline).foregroundStyle(.secondary)
                    Text(store.syncStatus).font(.caption).accessibilityIdentifier("cytology.sync.status")
                    Text(store.signedInForSync ? "Auto-sync on · every 30 seconds while open and online" : "Auto-sync requires sign-in with the same account as the website").font(.caption).accessibilityIdentifier("cytology.sync.enabled")
                    if store.signedInForSync {
                        Button(store.syncing ? "Syncing…" : "Sync now") { onSync?() }.disabled(store.syncing || onSync == nil).accessibilityIdentifier("cytology.sync.now")
                    } else {
                        Button("Sign in for sync") { onAccount?() }.disabled(onAccount == nil).accessibilityIdentifier("cytology.sync.signin")
                    }
                    Text("Sync capacity: 15 MB per collection. Images are optimized for storage; keep original microscope files separately.").font(.caption).foregroundStyle(.secondary)
                    Picker("Sample type", selection: $category) { Text("All").tag("All"); ForEach(Self.categories, id: \.self) { Text($0).tag($0) } }
                    Toggle("Favorites only", isOn: $favorites)
                    if store.items.isEmpty {
                        ContentUnavailableView("Start your image collection", systemImage: "photo.on.rectangle.angled", description: Text("Add an ear swab, lymph node sample, cellular structure or other microscopy image."))
                    } else if filtered.isEmpty { ContentUnavailableView.search(text: query) }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 14) {
                        ForEach(filtered) { item in
                            NavigationLink { CytologyDetail(store: store, itemID: item.id) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    if let data = item.photos.first?.jpeg, let image = UIImage(data: data) {
                                        Image(uiImage: image).resizable().scaledToFill().frame(height: 155).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    Text((item.favorite ? "★ " : "") + item.title).font(.headline).lineLimit(2)
                                    Text(item.category).font(.caption).foregroundStyle(.secondary)
                                    Text("\(item.photos.count) images").font(.caption).foregroundStyle(.secondary)
                                }.foregroundStyle(.primary)
                            }.accessibilityIdentifier("cytology.item.\(item.title)")
                        }
                    }
                }.padding()
            }
            .navigationTitle("Cytology Library")
            .searchable(text: $query, prompt: "Find labels, cells or notes")
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button { var item = ClinicProtocol(); item.category = "Ear cytology"; editing = item } label: { Label("Add images", systemImage: "plus") }.accessibilityIdentifier("cytology.new")
            } }
            .sheet(item: $editing) { CytologyEditor(store: store, initial: $0) }
            .alert("Cytology", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) { Button("OK") { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
        }
    }
}
private struct CytologyDetail: View {
    @ObservedObject var store: ClinicStore
    var onSync: (() -> Void)? = nil
    var onAccount: (() -> Void)? = nil
    let itemID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var editing: ClinicProtocol?
    @State private var deleting = false
    @State private var zoom: ClinicPhoto?
    var body: some View {
        Group {
            if let item = store.items.first(where: { $0.id == itemID }) {
                ScrollView { VStack(alignment: .leading, spacing: 18) {
                    Text(item.category).font(.headline).foregroundStyle(AppTheme.blue)
                    if !item.summary.isEmpty { Text(item.summary) }
                    ForEach(item.photos) { photo in
                        if let image = UIImage(data: photo.jpeg) {
                            Button { zoom = photo } label: { Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain)
                            Text(photo.caption).font(.headline)
                        }
                    }
                    if !item.notes.isEmpty { Text("Learning notes").font(.headline); Text(item.notes) }
                    if !item.author.isEmpty { Text("Species / stain / magnification: " + item.author).font(.subheadline) }
                    Text("User-labeled learning reference").font(.caption).foregroundStyle(.secondary)
                    Button(item.favorite ? "Remove favorite" : "Add to favorites") { store.toggleFavorite(item.id) }
                    Button("Delete entry", role: .destructive) { deleting = true }
                }.padding() }.navigationTitle(item.title).navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Edit") { editing = item } }
            } else { ContentUnavailableView("Entry removed", systemImage: "photo") }
        }
        .sheet(item: $editing) { CytologyEditor(store: store, initial: $0) }
        .sheet(item: $zoom) { photo in NavigationStack { CytologyZoom(data: photo.jpeg).navigationTitle(photo.caption).navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { zoom = nil } } } }
        .confirmationDialog("Delete this entry on all synced devices?", isPresented: $deleting) { Button("Delete", role: .destructive) { do { try store.delete(itemID); dismiss() } catch { store.errorMessage = error.localizedDescription } } }
    }
}
private struct CytologyZoom: UIViewRepresentable {
    let data: Data
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView(); scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 6; scroll.delegate = context.coordinator
        let image = UIImageView(image: UIImage(data: data)); image.contentMode = .scaleAspectFit; image.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(image)
        NSLayoutConstraint.activate([image.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), image.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor), image.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), image.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor), image.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor), image.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)])
        context.coordinator.image = image; return scroll
    }
    func updateUIView(_ uiView: UIScrollView, context: Context) {}
    final class Coordinator: NSObject, UIScrollViewDelegate { var image: UIImageView?; func viewForZooming(in scrollView: UIScrollView) -> UIView? { image } }
}
private struct CytologyEditor: View {
    @ObservedObject var store: ClinicStore
    var onSync: (() -> Void)? = nil
    var onAccount: (() -> Void)? = nil
    let initial: ClinicProtocol
    let base: ClinicProtocol?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ClinicProtocol
    @State private var selection: PhotosPickerItem?
    @State private var loading = false
    @State private var error: String?
    @State private var discard = false
    init(store: ClinicStore, initial: ClinicProtocol) { self.store = store; self.initial = initial; self.base = store.items.first { $0.id == initial.id }; _draft = State(initialValue: initial) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Sample") {
                    TextField("Entry title", text: $draft.title).accessibilityIdentifier("cytology.title")
                    Picker("Sample type", selection: $draft.category) { ForEach(CytologyLibraryView.categories, id: \.self) { Text($0).tag($0) } }
                    TextField("Finding / cell structure", text: $draft.summary, axis: .vertical)
                    TextField("Species, stain and magnification", text: $draft.author)
                }
                Section("Labeled images") {
                    ForEach($draft.photos) { $photo in
                        if let image = UIImage(data: photo.jpeg) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240) }
                        TextField("What does this image show?", text: $photo.caption, axis: .vertical)
                    }.onDelete { draft.photos.remove(atOffsets: $0) }
                    PhotosPicker(selection: $selection, matching: .images) { Label("Upload image", systemImage: "photo.badge.plus") }.disabled(loading || draft.photos.count >= 8)
                    Text("Add up to 8 images and label each one. Swipe an image row to remove it.").font(.caption)
                    if loading { ProgressView("Preparing image…") }
                }
                Section("Learning notes") { TextField("Features to remember or compare", text: $draft.notes, axis: .vertical).lineLimit(4...12) }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Cytology entry").navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(draft != initial)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if draft == initial { dismiss() } else { discard = true } } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    do {
                        guard !draft.photos.isEmpty, draft.photos.allSatisfy({ !$0.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw ClinicFileError.invalid("Add an image and a label for every image.") }
                        try store.save(draft, basedOn: base); dismiss()
                    } catch { self.error = error.localizedDescription }
                }.disabled(loading || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("cytology.save") }
            }
            .confirmationDialog("Discard unsaved changes?", isPresented: $discard) { Button("Discard", role: .destructive) { dismiss() } }
            .task(id: selection) {
                guard let selection else { return }; loading = true; defer { loading = false; self.selection = nil }
                do { guard let data = try await selection.loadTransferable(type: Data.self) else { throw ClinicFileError.invalid("Unable to load image.") }; let jpeg = try ClinicTransfer.preparePhoto(data); guard !Task.isCancelled else { return }; draft.photos.append(ClinicPhoto(jpeg: jpeg)) } catch { self.error = error.localizedDescription }
            }
        }
    }
}
