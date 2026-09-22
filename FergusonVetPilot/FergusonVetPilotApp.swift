import SwiftUI

@main
struct FergusonVetPilotApp: App {
    var body: some Scene {
        WindowGroup {
            AnimatedRootView()
                .tint(AppTheme.blue)
                .preferredColorScheme(.light)
        }
    }
}
