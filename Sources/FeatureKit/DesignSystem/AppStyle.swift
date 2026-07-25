import SwiftUI

public enum AppRadius {
    public static let card: CGFloat = 24
    public static let tile: CGFloat = 18
    public static let dropZone: CGFloat = 22
}

public struct SoftShadow: ViewModifier {
    public func body(content: Content) -> some View {
        content.shadow(
            color: Color.appChocolate.opacity(0.14),
            radius: 0, x: 3, y: 4
        )
    }
}

public extension View {
    func softShadow() -> some View { modifier(SoftShadow()) }
}

public struct KitschPressStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? -1.2 : 0))
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.58), value: configuration.isPressed)
    }
}
