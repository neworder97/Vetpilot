import SwiftUI

struct ContentView: View {
    @State private var tab = 0
    @StateObject private var clinicStore = ClinicStore()
    @StateObject private var scribe = ScribeStore()
    @StateObject private var account = VetPilotAccount()
    @State private var settings = false

    var body: some View {
        VStack(spacing: 0) {
            BrandHeader { settings = true }
            if scribe.hasActiveRecording {
                HStack(spacing: 12) {
                    Label(scribe.isRecording ? "Recording" : "Paused", systemImage: scribe.isRecording ? "record.circle.fill" : "pause.circle.fill")
                    Text(String(format: "%02d:%02d", Int(scribe.elapsed) / 60, Int(scribe.elapsed) % 60)).monospacedDigit()
                    Spacer()
                    Button(scribe.isRecording ? "Pause" : "Resume") { scribe.isRecording ? scribe.pause() : scribe.resume() }.accessibilityIdentifier("scribe.global.pause")
                    Button("Stop") { scribe.stop() }.accessibilityIdentifier("scribe.global.stop")
                }.font(.caption.bold()).padding(10).foregroundStyle(.white).background(scribe.isRecording ? Color.red : Color.orange)
                    .accessibilityIdentifier("scribe.recording.banner")
            }
            TabView(selection: $tab) {
                DoseView()
                    .tag(0)
                    .tabItem { Label("Dose", systemImage: "cross.case.fill") }

                MyClinicView(store: clinicStore)
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

                ScribeView(store: scribe, account: account)
                    .tag(5)
                    .tabItem { Label("Scribe", systemImage: "mic.fill") }
            }
        }
        .background(Color.white)
        .overlay { if scribe.isRecording { Rectangle().strokeBorder(.red, lineWidth: 4).ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true) } }
        .sheet(isPresented: $settings) { AccountSettingsView(account: account, scribe: scribe) }
        .task { do { try scribe.switchAccount(account.userID) } catch { scribe.error = error.localizedDescription } }
        .onChange(of: account.userID) { _, id in do { try scribe.switchAccount(id) } catch { scribe.error = error.localizedDescription } }
        .alert("Scribe", isPresented: Binding(get: { scribe.error != nil }, set: { if !$0 { scribe.error = nil } })) {
            Button("OK") { scribe.error = nil }
        } message: { Text(scribe.error ?? "") }
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
