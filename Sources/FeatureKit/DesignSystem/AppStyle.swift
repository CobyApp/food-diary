import SwiftUI

public enum AppRadius {
    public static let card: CGFloat = 20
    public static let tile: CGFloat = 15
    public static let dropZone: CGFloat = 16
}

public struct SoftShadow: ViewModifier {
    public func body(content: Content) -> some View {
        content.shadow(
            color: Color(.sRGB, red: 150 / 255, green: 120 / 255, blue: 180 / 255, opacity: 0.14),
            radius: 12, x: 0, y: 5
        )
    }
}

public extension View {
    func softShadow() -> some View { modifier(SoftShadow()) }
}
