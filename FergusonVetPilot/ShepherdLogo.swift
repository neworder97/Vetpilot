import SwiftUI

struct ShepherdLogo: View {
    var size: CGFloat = 56

    var body: some View {
        Image("ShepherdIcon")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: max(1.5, size * 0.025))
            }
            .accessibilityLabel("VetPilot German Shepherd logo")
    }
}
