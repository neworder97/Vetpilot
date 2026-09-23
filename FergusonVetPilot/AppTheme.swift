import SwiftUI

enum AppTheme {
    static let blue = Color(red: 13/255, green: 71/255, blue: 161/255)
    static let orange = Color(red: 1, green: 140/255, blue: 0)
    static let pale = Color(red: 244/255, green: 248/255, blue: 253/255)
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(AppTheme.pale, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func vetCard() -> some View { modifier(CardModifier()) }
}
