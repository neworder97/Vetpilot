import SwiftUI

struct CollectionExportView: View {
    @ObservedObject var store: ClinicStore
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var selected = Set<UUID>()
    @State private var sharing: ClinicShare?
    @State private var error: String?
    private var items: [ClinicProtocol] { store.items.filter { selected.contains($0.id) } }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Select one or more items to export. Editable files include photos and labels.")
                    HStack {
                        Button("Select all") { selected = Set(store.items.map(\.id)) }
                        Spacer()
                        Button("Clear selection") { selected.removeAll() }
                    }.buttonStyle(.borderless)
                    Text("\(items.count) of \(store.items.count) selected").accessibilityIdentifier("export.selection.count")
                }
                Section("Items") {
                    ForEach(store.items) { item in
                        Toggle(isOn: Binding(get: { selected.contains(item.id) }, set: { if $0 { selected.insert(item.id) } else { selected.remove(item.id) } })) {
                            VStack(alignment: .leading) {
                                Text(item.title)
                                Text("\(item.category) · \(item.photos.count) photos").font(.caption).foregroundStyle(.secondary)
                            }
                        }.accessibilityIdentifier("export.select.\(item.title)")
                    }
                }
                Section("Export selected") {
                    Button("Export selected as PDF") { export(pdf: true) }.disabled(items.isEmpty)
                    Button("Export selected as editable file") { export(pdf: false) }.disabled(items.isEmpty).accessibilityIdentifier("export.selected.file")
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Export \(title)").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $sharing) { ClinicShareSheet(urls: $0.urls) }
        }
    }
    private func export(pdf: Bool) {
        guard !items.isEmpty else { return }
        do { sharing = ClinicShare(urls: [try ClinicTransfer.export(items, pdf: pdf)]) }
        catch { self.error = error.localizedDescription }
    }
}
