import SwiftUI

struct LaunchAnimationView: View {
    let onFinished: () -> Void

    @State private var logoScale: CGFloat = 0.72
    @State private var logoOpacity = 0.0
    @State private var textOpacity = 0.0
    @State private var glow = false
    @State private var exitScale: CGFloat = 1.0
    @State private var exitOpacity = 1.0

    private var captureMode: Bool {
        ProcessInfo.processInfo.environment["VETPILOT_CAPTURE_LAUNCH"] == "1"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.blue, AppTheme.blue.opacity(0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                ShepherdLogo(size: 132)
                    .scaleEffect(logoScale * exitScale)
                    .opacity(logoOpacity * exitOpacity)
                    .shadow(
                        color: AppTheme.orange.opacity(glow ? 0.40 : 0.12),
                        radius: glow ? 26 : 8
                    )

                VStack(spacing: 6) {
                    Text("VetPilot")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Veterinary clinical support")
                        .font(.subheadline.weight(.medium))
                        .opacity(0.86)
                }
                .foregroundStyle(.white)
                .opacity(textOpacity * exitOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.70, dampingFraction: 0.78)) {
                logoScale = 1.0
                logoOpacity = 1.0
                glow = true
            }
            withAnimation(.easeOut(duration: 0.55).delay(0.25)) {
                textOpacity = 1.0
            }

            let hold = captureMode ? 4.0 : 1.45
            DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
                withAnimation(.easeInOut(duration: 0.42)) {
                    exitScale = 1.12
                    exitOpacity = 0.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + hold + 0.37) {
                onFinished()
            }
        }
    }
}

struct AnimatedRootView: View {
    @State private var showingLaunch = true

    var body: some View {
        ZStack {
            ContentView()
                .opacity(showingLaunch ? 0 : 1)
                .scaleEffect(showingLaunch ? 0.985 : 1.0)

            if showingLaunch {
                LaunchAnimationView {
                    withAnimation(.easeOut(duration: 0.32)) {
                        showingLaunch = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }
}

