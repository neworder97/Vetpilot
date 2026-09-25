import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @StateObject private var clinicStore = ClinicStore()
    @StateObject private var cytology = ClinicStore(collection: "cytology")
    @StateObject private var account = VetPilotAccount()
    @State private var settings = false

    var body: some View {
        VStack(spacing: 0) {
            BrandHeader { settings = true }
            TabView(selection: $tab) {
                DoseView()
                    .tag(0)
                    .tabItem { Label("Dose", systemImage: "cross.case.fill") }

                MyClinicView(store: clinicStore).id(account.userID)
                    .tag(1)
                    .tabItem { Label("My Clinic", systemImage: "list.clipboard.fill") }

                BreedView()
                    .tag(2)
                    .tabItem { Label("Breeds", systemImage: "pawprint.fill") }

                NutritionView()
                    .tag(3)
                    .tabItem { Label("Nutrition", systemImage: "scalemass.fill") }

                LabworkView()
                    .tag(4)
                    .tabItem { Label("Labwork", systemImage: "testtube.2") }

                CytologyLibraryView(store: cytology).id(account.userID)
                    .tag(5)
                    .tabItem { Label("Cytology", systemImage: "photo.on.rectangle.angled") }
            }
        }
        .background(Color.white)
        .sheet(isPresented: $settings) { AccountSettingsView(account: account) }
        .task(id: account.userID) {
            clinicStore.switchAccount(account.userID); cytology.switchAccount(account.userID)
            while !Task.isCancelled {
                await clinicStore.sync(account: account); await cytology.sync(account: account)
                do { try await Task.sleep(nanoseconds: 60_000_000_000) } catch { break }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await clinicStore.sync(account: account); await cytology.sync(account: account) } }
        }
        .onChange(of: account.userID) { _, id in clinicStore.switchAccount(id); cytology.switchAccount(id) }
        .onOpenURL { url in
            guard url.isFileURL || url.scheme != "vetpilot" else { return }
            tab = 1
            clinicStore.prepareImport(url)
        }
    }
}

private struct BrandHeader: View {
    let settings: () -> Void
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
            Button(action: settings) { Image(systemName: "gearshape.fill").foregroundStyle(.white).padding(8) }
                .accessibilityLabel("Settings").accessibilityIdentifier("app.settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.blue)
    }
}
