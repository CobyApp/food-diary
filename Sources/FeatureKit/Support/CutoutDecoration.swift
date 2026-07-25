import Foundation

public enum CutoutDecoration: String, CaseIterable, Equatable, Sendable {
    case none
    case sparkle
    case heart
    case star
    case ribbon

    public var label: String? {
        self == .none ? nil : rawValue
    }

    public var symbol: String? {
        switch self {
        case .none: return nil
        case .sparkle: return "sparkles"
        case .heart: return "heart.fill"
        case .star: return "star.fill"
        case .ribbon: return "gift.fill"
        }
    }

    public var next: CutoutDecoration {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    public init(label: String?) {
        switch label {
        case "\u{2728}": self = .sparkle
        case "\u{1F497}": self = .heart
        case "\u{2B50}\u{FE0F}": self = .star
        case "\u{1F331}": self = .ribbon
        default: self = Self(rawValue: label ?? "") ?? .none
        }
    }
}
