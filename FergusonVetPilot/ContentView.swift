import SwiftUI

struct ContentView: View {
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            BrandHeader()
            TabView(selection: $tab) {
                DoseView()
                    .tag(0)
                    .tabItem { Label("Dose", systemImage: "cross.case.fill") }

                RadiologyView()
                    .tag(1)
                    .tabItem { Label("X-Ray", systemImage: "waveform.path.ecg.rectangle") }

                BreedView()
                    .tag(2)
                    .tabItem { Label("Breeds", systemImage: "pawprint.fill") }

                NutritionView()
                    .tag(3)
                    .tabItem { Label("Nutrition", systemImage: "scalemass.fill") }

                LabworkView()
                    .tag(4)
                    .tabItem { Label("Labwork", systemImage: "testtube.2") }
            }
        }
        .background(Color.white)
    }
}

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            ShepherdLogo(size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("VetPilot")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("Veterinary clinical support")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.blue)
    }
}

