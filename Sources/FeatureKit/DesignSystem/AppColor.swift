import SwiftUI

public extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    static let appMilk = Color(hex: 0xFFF9F0)
    static let appCard = Color(hex: 0xFFFEFA)
    static let appBlue = Color(hex: 0xA8C7E8)
    static let appBlueInk = Color(hex: 0x507AA7)
    static let appPink = Color(hex: 0xF7B7C8)
    static let appPinkInk = Color(hex: 0xB64D6A)
    static let appButter = Color(hex: 0xF7D889)
    static let appButterInk = Color(hex: 0x9D6D19)
    static let appLavender = Color(hex: 0xC9B9E8)
    static let appCherry = Color(hex: 0xD94A61)
    static let appChocolate = Color(hex: 0x62483F)
    static let appInk = Color(hex: 0x493E3B)
    static let appMuted = Color(hex: 0x948782)

    static let appTilePink = Color(hex: 0xFDEBF2)
    static let appTileBlue = Color(hex: 0xEAF3FC)
    static let appTileButter = Color(hex: 0xFCF3D6)
}

// Bridge the palette into ShapeStyle so `.foregroundStyle(.appInk)`,
// `.fill(.appBlue)` etc. resolve via implicit-member shorthand (a plain
// `Color` static does not satisfy a generic `ShapeStyle` parameter).
public extension ShapeStyle where Self == Color {
    static var appMilk: Color { .appMilk }
    static var appCard: Color { .appCard }
    static var appBlue: Color { .appBlue }
    static var appBlueInk: Color { .appBlueInk }
    static var appPink: Color { .appPink }
    static var appPinkInk: Color { .appPinkInk }
    static var appButter: Color { .appButter }
    static var appButterInk: Color { .appButterInk }
    static var appLavender: Color { .appLavender }
    static var appCherry: Color { .appCherry }
    static var appChocolate: Color { .appChocolate }
    static var appInk: Color { .appInk }
    static var appMuted: Color { .appMuted }
    static var appTilePink: Color { .appTilePink }
    static var appTileBlue: Color { .appTileBlue }
    static var appTileButter: Color { .appTileButter }
}

public enum StickerTint: CaseIterable {
    case pink, blue, butter, plain

    public var color: Color {
        switch self {
        case .pink: return .appTilePink
        case .blue: return .appTileBlue
        case .butter: return .appTileButter
        case .plain: return .appCard
        }
    }

    public static func rotating(_ index: Int) -> StickerTint {
        allCases[((index % allCases.count) + allCases.count) % allCases.count]
    }
}
