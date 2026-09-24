import SwiftUI

struct ClinicDetailView: View {
    @ObservedObject var store: ClinicStore
    let itemID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var checked: Set<UUID> = []
    @State private var editing = false
    @State private var deleteConfirm = false
    @State private var sharing: ClinicShare?
    @State private var error: String?
    private var item: ClinicProtocol? { store.items.first { $0.id == itemID } }

    var body: some View {
        Group {
            if let item {
                List {
                    Section {
                        Text(item.title).font(.title2.bold()).foregroundStyle(AppTheme.blue)
                        Text("\(item.kind) • \(item.category) • Version \(item.revision)").font(.subheadline)
                        Text(ClinicProtocol.reviewNotice).font(.caption).foregroundStyle(AppTheme.orange)
                        if !item.summary.isEmpty { Text(item.summary) }
                    }
                    Section("Checklist • \(item.steps.filter { checked.contains($0.id) }.count)/\(item.steps.count)") {
                        if item.steps.isEmpty { Text("No steps entered.").foregroundStyle(.secondary) }
                        ForEach(Array(item.steps.enumerated()), id: \.element.id) { index, step in
                            checkRow(id: step.id, title: "\(index + 1). \(step.text)")
                        }
                    }
                    Section("Equipment") {
                        if item.equipment.isEmpty { Text("No equipment entered.").foregroundStyle(.secondary) }
                        ForEach(item.equipment) { equipment in
                            VStack(alignment: .leading, spacing: 4) {
                                checkRow(id: equipment.id, title: equipment.name)
                                Text("Quantity: \(equipment.quantity) • Size: \(equipment.size)").font(.caption)
                                if !equipment.location.isEmpty { Text("Location: \(equipment.location)").font(.caption) }
                            }
                        }
                    }
                    Section {
                        Button("Reset checklist") { checked.removeAll() }.accessibilityIdentifier("clinic.checklist.reset")
                        Text("Checkmarks are temporary for this view. They are not a patient record and are not included in exports.").font(.caption).foregroundStyle(.secondary)
                    }
                    if !item.notes.isEmpty { Section("Notes") { Text(item.notes).textSelection(.enabled) } }
                    if !item.photos.isEmpty {
                        Section("Reference photos") {
                            ForEach(item.photos) { photo in
                                if let image = UIImage(data: photo.jpeg) { Image(uiImage: image).resizable().scaledToFit() }
                                if !photo.caption.isEmpty { Text(photo.caption).font(.caption) }
                            }
                        }
                    }
                    Section("Attribution & review") {
                        LabeledContent("Author", value: item.author.isEmpty ? "Not entered" : item.author)
                        LabeledContent("Reviewer", value: item.reviewer.isEmpty ? "Not entered" : item.reviewer)
                        LabeledContent("Review date", value: item.reviewedOn.isEmpty ? "Not entered" : item.reviewedOn)
                        LabeledContent("Last edited", value: item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        Text("Review details are user-entered, not a verified signature or endorsement. Clinical content edits clear unchanged prior review details.").font(.caption)
                        if item.imported { Text("Imported copy; changes do not update the sender's version.").font(.caption) }
                    }
                    Section("Share / export") {
                        Button { export(item, pdf: true) } label: { Label("Share PDF", systemImage: "doc.richtext") }
                            .accessibilityIdentifier("clinic.share.pdf")
                        Button { export(item, pdf: false) } label: { Label("Share editable .vetpilot file", systemImage: "square.and.arrow.up") }
                            .accessibilityIdentifier("clinic.share.file")
                        Text("Choose Mail, AirDrop, Messages or Save to Files in the share sheet. Teammates can open the .vetpilot file in VetPilot or import it from My Clinic.").font(.caption)
                    }
                    Section { Button("Delete item", role: .destructive) { deleteConfirm = true } }
                }
                .navigationTitle("My Clinic item")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { store.toggleFavorite(itemID) } label: { Image(systemName: item.favorite ? "star.fill" : "star") }
                            .accessibilityLabel(item.favorite ? "Remove favorite" : "Add favorite")
                            .accessibilityIdentifier("clinic.favorite")
                        Button("Edit") { editing = true }.accessibilityIdentifier("clinic.edit")
                    }
                }
                .sheet(isPresented: $editing) { ClinicEditorView(store: store, initial: item) }
                .onChange(of: item.revision) { _, _ in checked.removeAll() }
            } else { ContentUnavailableView("Item not found", systemImage: "doc.questionmark") }
        }
        .onAppear { store.opened(itemID) }
        .sheet(item: $sharing) { ClinicShareSheet(urls: $0.urls) }
        .confirmationDialog("Delete this item from this device?", isPresented: $deleteConfirm, titleVisibility: .visible) {
            Button("Delete item", role: .destructive) {
                do { try store.delete(itemID); dismiss() } catch { self.error = error.localizedDescription }
            }
        }
        .alert("My Clinic", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
    private func checkRow(id: UUID, title: String) -> some View {
        Button {
            if checked.contains(id) { checked.remove(id) } else { checked.insert(id) }
        } label: {
            HStack(alignment: .top) {
                Image(systemName: checked.contains(id) ? "checkmark.circle.fill" : "circle")
                Text(title).foregroundStyle(.primary)
            }
        }.buttonStyle(.plain)
            .accessibilityValue(checked.contains(id) ? "Checked" : "Not checked")
    }
    private func export(_ item: ClinicProtocol, pdf: Bool) {
        do { sharing = ClinicShare(urls: [try ClinicTransfer.export([item], pdf: pdf)]) }
        catch { self.error = error.localizedDescription }
    }
}
