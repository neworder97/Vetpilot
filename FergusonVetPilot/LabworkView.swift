import SwiftUI

struct LabworkView: View {
    @State private var query = ""
    @State private var provider = "All"

    private var results: [LabTestEntry] {
        LabworkCatalog.search(query, provider: LabProvider(rawValue: provider))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Specimen quick reference")
                        .font(.title2.bold()).foregroundStyle(AppTheme.blue)
                    Text("Selected dog/cat tests, including U.S. IDEXX send-out wellness, senior, geriatric and cardiac panels. Check the current order before collection; panels and requirements can change.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Picker("Laboratory", selection: $provider) {
                        Text("All").tag("All")
                        Text("IDEXX").tag("IDEXX")
                        Text("Michigan State").tag("MSU")
                    }.pickerStyle(.segmented)
                    Text("\(results.count) tests • reviewed \(LabworkCatalog.reviewed)")
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("labwork.count")
                }
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
                ForEach(LabProvider.allCases) { lab in
                    let group = results.filter { $0.provider == lab.rawValue }
                    if !group.isEmpty {
                        Section(lab.title) {
                            ForEach(group) { test in
                                NavigationLink {
                                    LabTestDetail(test: test)
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(test.name).font(.headline)
                                        Text("\(test.code) • \(test.species)")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Text(test.available ? test.amount : "Unavailable — do not submit")
                                            .font(.subheadline)
                                            .foregroundStyle(test.available ? AppTheme.blue : AppTheme.orange)
                                    }.padding(.vertical, 3)
                                }.accessibilityIdentifier("labwork.test.\(test.id)")
                            }
                        }
                    }
                }
                Section("Full laboratory directories") {
                    Link("IDEXX • public U.S. test directory", destination: URL(string: "https://www.idexx.com/en/veterinary/reference-laboratories/tests-and-services/")!)
                    Link("IDEXX • VetConnect PLUS", destination: URL(string: "https://www.vetconnectplus.com/")!)
                    Link("Michigan State • complete catalog", destination: URL(string: "https://vdl.msu.edu/Bin/Catalog.exe")!)
                    Text("If a test or required volume is not listed, use the official directory or contact the laboratory. Do not substitute another test’s specimen rules.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Labwork")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Test, code, specimen or tube")
        }
    }
}

private struct LabTestDetail: View {
    let test: LabTestEntry

    var body: some View {
        Form {
            Section {
                Text(test.name).font(.title2.bold()).foregroundStyle(AppTheme.blue)
                Text("\(test.provider) • \(test.code) • \(test.species)")
                    .font(.subheadline).foregroundStyle(.secondary)
                if !test.available {
                    Label("Unavailable — do not submit", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.orange)
                }
                Text(test.purpose)
            }
            if !test.components.isEmpty {
                Section("Tests included") {
                    Text(test.components).accessibilityIdentifier("labwork.components")
                }
            }
            if test.available {
                Section("Specimen and amount") {
                    Text(test.specimen).font(.headline)
                    Text(test.amount).accessibilityIdentifier("labwork.amount")
                    Label(test.tube, systemImage: test.specimen.contains("slides") || test.specimen.contains("Slides") ? "rectangle.on.rectangle" : "testtube.2")
                        .foregroundStyle(AppTheme.blue)
                    Text(LabworkCatalog.tubeNote).font(.footnote).foregroundStyle(.secondary)
                }
                Section("Clot, spin and separate") {
                    Text(LabworkCatalog.preparation(test.preparation))
                        .accessibilityIdentifier("labwork.preparation")
                }
                Section("Storage and shipping") { Text(test.handling) }
            }
            if !test.notes.isEmpty { Section("Test-specific notes") { Text(test.notes) } }
            Section("Official instructions") {
                if let url = URL(string: test.source) {
                    Link("Open this test’s official source", destination: url)
                }
                if test.provider == "IDEXX", let url = URL(string: LabworkCatalog.idexxGuide) {
                    Link("IDEXX specimen preparation guide", destination: url)
                    Text("Use the exact test code in the current U.S. directory or your VetConnect PLUS order. Standard CBC and CBC-Select profiles have different codes.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Text("Source reviewed \(LabworkCatalog.reviewed). Confirm the current order, patient requirements, and local handling procedure before drawing.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(test.code)
        .navigationBarTitleDisplayMode(.inline)
    }
}
