import SwiftUI

public enum AppRadius {
    public static let card: CGFloat = 24
    public static let tile: CGFloat = 18
    public static let dropZone: CGFloat = 22
    public static let button: CGFloat = 18
}

public struct SoftShadow: ViewModifier {
    public func body(content: Content) -> some View {
        // Flattened first, so the sticker casts one silhouette. Without this,
        // SwiftUI applies the shadow to every layer underneath, which stamps a
        // hard offset copy of each glyph onto the card the text sits on.
        content
            .compositingGroup()
            .shadow(
                color: Color.appChocolate.opacity(0.14),
                radius: 0, x: 3, y: 4
            )
    }
}

public extension View {
    func softShadow() -> some View { modifier(SoftShadow()) }
}

public struct KitschPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .rotationEffect(.degrees(configuration.isPressed && !reduceMotion ? -0.8 : 0))
            .brightness(configuration.isPressed ? -0.03 : 0)
            .opacity(isEnabled ? 1 : 0.52)
            .animation(
                reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.22, dampingFraction: 0.64),
                value: configuration.isPressed
            )
    }
}

public struct KitschFilledButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let color: Color
    private let fullWidth: Bool
    private let verticalPadding: CGFloat

    public init(
        color: Color = .appCherry,
        fullWidth: Bool = true,
        verticalPadding: CGFloat = 14
    ) {
        self.color = color
        self.fullWidth = fullWidth
        self.verticalPadding = verticalPadding
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 18)
            .padding(.vertical, verticalPadding)
            .background(isEnabled ? color : Color.appMuted.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(Color.appCard, lineWidth: 3)
                    .padding(2)
            }
            .shadow(
                color: isEnabled ? Color.appChocolate.opacity(0.18) : .clear,
                radius: 0,
                x: 3,
                y: 4
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .opacity(isEnabled ? 1 : 0.66)
            .animation(
                reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.22, dampingFraction: 0.66),
                value: configuration.isPressed
            )
    }
}

public struct KitschOutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let color: Color
    private let fullWidth: Bool
    private let verticalPadding: CGFloat

    public init(
        color: Color = .appPinkInk,
        fullWidth: Bool = false,
        verticalPadding: CGFloat = 11
    ) {
        self.color = color
        self.fullWidth = fullWidth
        self.verticalPadding = verticalPadding
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appSection)
            .foregroundStyle(isEnabled ? color : Color.appMuted)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 18)
            .padding(.vertical, verticalPadding)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(isEnabled ? color.opacity(0.72) : Color.appMuted.opacity(0.35), lineWidth: 2)
            }
            .shadow(color: Color.appChocolate.opacity(0.10), radius: 0, x: 2, y: 3)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .opacity(isEnabled ? 1 : 0.6)
            .animation(
                reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.22, dampingFraction: 0.66),
                value: configuration.isPressed
            )
    }
}
