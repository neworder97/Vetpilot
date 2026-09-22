import SwiftUI

struct BreedView: View {
    @State private var species: Species = .dog
    @State private var search = ""

    private var results: [BreedEntry] {
        ClinicalData.searchBreeds(species: species, query: search)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Breed predisposition library")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.blue)
                        Text("Educational associations for differential thinking—not a diagnosis or prediction for an individual patient.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Species", selection: $species) {
                        ForEach(Species.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search breed or condition…", text: $search)
                    }
                    .padding(11)
                    .background(AppTheme.pale, in: RoundedRectangle(cornerRadius: 12))

                    LazyVStack(spacing: 10) {
                        ForEach(results) { breed in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(breed.name)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.blue)
                                Text(breed.conditions)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(breed.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .vetCard()
                        }
                    }
                }
                .padding(16)
            }
            .navigationBarHidden(true)
        }
    }
}
