import SwiftUI

@main
struct FergusonVetPilotApp: App {
    @StateObject private var sync = VetPilotSyncController()
    var body: some Scene {
        WindowGroup {
            AnimatedRootView()
                .environmentObject(sync)
                .environmentObject(sync.account)
                .tint(AppTheme.blue)
                .preferredColorScheme(.light)
        }
        .backgroundTask(.appRefresh(VetPilotSyncController.refreshIdentifier)) {
            await sync.runBackgroundRefresh()
        }
    }
}
