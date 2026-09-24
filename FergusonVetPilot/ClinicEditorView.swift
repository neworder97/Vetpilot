import SwiftUI
import PhotosUI

struct ClinicEditorView: View {
    @ObservedObject var store: ClinicStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ClinicProtocol
    @State private var photoSelection: PhotosPickerItem?
    @State private var loadingPhoto = false
    @State private var error: String?
    @State private var discard = false
    private let initial: ClinicProtocol
    private let syncBase: ClinicProtocol?

    init(store: ClinicStore, initial: ClinicProtocol) {
        self.store = store; self.initial = initial
        self.syncBase = store.items.first { $0.id == initial.id }
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Title", text: $draft.title).accessibilityIdentifier("clinic.editor.title")
                    Picker("Type", selection: $draft.kind) { ForEach(ClinicProtocol.kinds, id: \.self) { Text($0).tag($0) } }
                    Picker("Category", selection: $draft.category) {
                        ForEach(Array(Set(ClinicProtocol.categories + [draft.category])).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Purpose / summary", text: $draft.summary, axis: .vertical)
                    Text(ClinicProtocol.reviewNotice).font(.caption).foregroundStyle(AppTheme.orange)
                }
                Section("Ordered checklist") {
                    ForEach($draft.steps) { $step in
                        TextField("Step", text: $step.text, axis: .vertical)
                            .accessibilityIdentifier("clinic.editor.step")
                    }
                    .onDelete { draft.steps.remove(atOffsets: $0) }
                    .onMove { draft.steps.move(fromOffsets: $0, toOffset: $1) }
                    Button("Add step") { draft.steps.append(ClinicStep()) }
                        .disabled(draft.steps.count >= 200).accessibilityIdentifier("clinic.editor.add.step")
                    Text("Tap Edit to reorder steps or remove rows.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Equipment list") {
                    ForEach($draft.equipment) { $equipment in
                        VStack(alignment: .leading) {
                            TextField("Equipment name", text: $equipment.name).accessibilityIdentifier("clinic.editor.equipment")
                            TextField("Quantity", text: $equipment.quantity)
                            TextField("Size / specification", text: $equipment.size)
                            TextField("Storage location", text: $equipment.location)
                        }
                    }
                    .onDelete { draft.equipment.remove(atOffsets: $0) }
                    .onMove { draft.equipment.move(fromOffsets: $0, toOffset: $1) }
                    Button("Add equipment") { draft.equipment.append(ClinicEquipment()) }
                        .disabled(draft.equipment.count >= 200).accessibilityIdentifier("clinic.editor.add.equipment")
                    Menu("Insert reusable equipment set") {
                        ForEach(store.items.filter { $0.kind == "Equipment set" }) { set in
                            Button(set.title) {
                                draft.equipment += set.equipment.map { equipment in
                                    var copy = equipment; copy.id = UUID(); return copy
                                }
                            }.disabled(draft.equipment.count + set.equipment.count > 200)
                        }
                    }.disabled(!store.items.contains { $0.kind == "Equipment set" })
                }
                Section("Notes") {
                    TextField("Notes / references", text: $draft.notes, axis: .vertical).lineLimit(3...10)
                        .accessibilityIdentifier("clinic.editor.notes")
                }
                Section("Reference photos") {
                    ForEach($draft.photos) { $photo in
                        if let image = UIImage(data: photo.jpeg) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180) }
                        TextField("Photo caption", text: $photo.caption)
                    }.onDelete { draft.photos.remove(atOffsets: $0) }
                    PhotosPicker(selection: $photoSelection, matching: .images) {
                        Label("Add photo", systemImage: "photo.badge.plus")
                    }.disabled(loadingPhoto || draft.photos.count >= 8)
                    if loadingPhoto { ProgressView("Preparing photo…") }
                    Text("Up to eight reference photos. Shared files include these photos; avoid patient or client identifying information.").font(.caption)
                }
                Section("Attribution & review") {
                    TextField("Author", text: $draft.author)
                    TextField("Reviewer (optional)", text: $draft.reviewer)
                    TextField("Review date (optional)", text: $draft.reviewedOn)
                    Text("Enter review details only after review. Editing content clears unchanged prior reviewer/date fields; a newly entered review is user-supplied, not a verified signature.").font(.caption)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(store.items.contains { $0.id == draft.id } ? "Edit clinic item" : "New clinic item")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(draft != initial)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if draft == initial { dismiss() } else { discard = true } }
                }
                ToolbarItem(placement: .primaryAction) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try store.save(draft, basedOn: syncBase); dismiss() } catch { self.error = error.localizedDescription }
                    }.disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loadingPhoto)
                        .accessibilityIdentifier("clinic.editor.save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .accessibilityIdentifier("clinic.keyboard.done")
                }
            }
            .confirmationDialog("Discard unsaved changes?", isPresented: $discard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
            }
            .task(id: photoSelection) {
                guard let selection = photoSelection else { return }
                loadingPhoto = true
                defer { loadingPhoto = false; photoSelection = nil }
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self) else { throw ClinicFileError.invalid("Unable to load photo.") }
                    let jpeg = try ClinicTransfer.preparePhoto(data)
                    guard !Task.isCancelled else { return }
                    draft.photos.append(ClinicPhoto(jpeg: jpeg))
                } catch { self.error = error.localizedDescription }
            }
        }
    }
}
