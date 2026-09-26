import SwiftUI

struct VetPilotAboutView: View {
    var body: some View {
        List {
            Section("Built for the work around patient care") {
                Text("VetPilot brings everyday clinical tools together for veterinarians and veterinary technicians, on the web and on a phone.")
            }
            Section("Why it was made") {
                Text("Veterinary teams move between calculations, sample preparation, procedures, and teaching throughout the day. VetPilot was made to reduce repeated lookup and manual calculation, and to give useful clinic knowledge a place to live.")
                Text("The aim is practical: help the team prepare, organize, and review their work while keeping clinical decisions with the veterinarian.")
            }
            Section("How it’s used") {
                Text("Calculate medication candidates and nutrition estimates. Check laboratory specimen instructions. Build procedures in My Clinic and keep labeled microscopy images in Cytology for learning.")
                Text("Share protocols with teammates, print nutrition plans, and access synced My Clinic and Cytology collections using the same account on the website and app.")
            }
            Section("Support for professional judgment") {
                Text("VetPilot is a clinical support and learning tool. A calculated result is not a prescription or diagnosis. The treating veterinarian must confirm the patient, indication, species, route, formulation, concentration, and current source before use. Cytology labels describe the user’s observations.")
                Text("References are credited to their authors, publishers, and organizations. Their inclusion does not imply affiliation, endorsement, or independent validation of VetPilot.")
            }
            Section("Contact") {
                Link("vetpilotinfo@gmail.com", destination: URL(string: "mailto:vetpilotinfo@gmail.com")!)
                Link("vetpilotapp.org", destination: URL(string: "https://vetpilotapp.org")!)
            }
        }.navigationTitle("About VetPilot")
    }
}

struct VetPilotSourceEntry: Decodable {
    let title: String
    let detail: String
    let references: [String]
}
struct VetPilotSourcesView: View {
    @State private var query = ""
    private static let entries: [VetPilotSourceEntry] = {
        guard let url = Bundle.main.url(forResource: "WebsiteSourceDirectory", withExtension: "json"), let data = try? Data(contentsOf: url), let entries = try? JSONDecoder().decode([VetPilotSourceEntry].self, from: data) else { return [] }
        return entries
    }()
    private let equations = [
        ("Medication weight conversion", "kg = lb × 0.45359237"),
        ("Weight-based medication amount", "Amount = selected dose per kg × weight in kg"),
        ("Tablets / capsules", "Quantity = calculated mg ÷ mg per unit"),
        ("Liquid / injectable volume", "mL = compatible calculated amount ÷ concentration per mL"),
        ("Resting energy requirement", "RER = 70 × weight in kg^0.75"),
        ("Nutrition weight conversion", "kg = lb ÷ 2.205"),
        ("Daily food amount", "Food units/day = kcal/day ÷ kcal per food unit")
    ]
    private var filtered: [VetPilotSourceEntry] {
        Self.entries.filter { query.isEmpty || ([$0.title, $0.detail] + $0.references).joined(separator: " ").localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        List {
            Section("Sources & credits") {
                Text("Trace the reference. Review the math. Credit to the authors, publishers, and organizations behind the references recorded in VetPilot.")
                Text("A product label supporting a strength does not by itself support an extra-label dose or indication. Listing a source does not imply endorsement or independent clinical review.").font(.footnote)
            }
            Section("How calculations are built") {
                ForEach(equations, id: \.0) { equation in
                    VStack(alignment: .leading, spacing: 5) { Text(equation.0).font(.headline); Text(equation.1) }
                }
                Text("The selected tool shows the applicable protocol, units, and calculation details. Fixed doses, labeled weight bands, infusions, rounding, and nutrition body-condition and calorie-floor rules require the specific tool’s guidance.").font(.footnote)
                Link("Pet Nutrition Alliance calorie calculator", destination: URL(string: "https://petnutritionalliance.org/resources/calorie-calculator/")!)
                Link("PNA calorie equations", destination: URL(string: "https://petnutritionalliance.org/wp-content/uploads/2023/03/MER.RER_.PNA_.pdf")!)
            }
            Section("Reference directory · \(filtered.count) entries") {
                ForEach(Array(filtered.enumerated()), id: \.offset) { _, entry in
                    DisclosureGroup {
                        ForEach(entry.references.filter { !$0.isEmpty }, id: \.self) { reference in
                            Text(.init(reference)).textSelection(.enabled)
                        }
                    } label: { VStack(alignment: .leading) { Text(entry.title); Text(entry.detail).font(.caption).foregroundStyle(.secondary) } }
                }
                if filtered.isEmpty { Text("No matching references. Try a medication name or a broader search.") }
            }
            Section("Laboratory references & attribution") {
                Text("Follow the current receiving laboratory’s instructions. Names and publications belong to their respective owners. Broad or missing citations are not verified drug monographs. Custom medications retain the source entered by the clinic in Dose.")
            }
        }.navigationTitle("Sources").searchable(text: $query, prompt: "Medication, protocol or source")
    }
}
