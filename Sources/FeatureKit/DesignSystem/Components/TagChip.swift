import SwiftUI
import Models

/// A tag as it appears on a meal. Colour comes from the name, so the same tag
/// always looks the same without storing a colour for it.
public struct TagChip: View {
    private let name: String
    private let size: Size

    public enum Size {
        case small
        case regular

        var font: Font {
            switch self {
            case .small: return .system(size: 10, weight: .heavy, design: .rounded)
            case .regular: return .system(size: 12, weight: .heavy, design: .rounded)
            }
        }

        var horizontalPadding: CGFloat { self == .small ? 7 : 10 }
        var verticalPadding: CGFloat { self == .small ? 3 : 6 }
    }

    public init(_ name: String, size: Size = .regular) {
        self.name = name
        self.size = size
    }

    private static let palette: [(fill: Color, ink: Color)] = [
        (.appPink, .appPinkInk),
        (.appBlue, .appBlueInk),
        (.appButter, .appButterInk),
        (.appLavender, .appChocolate),
    ]

    private var colors: (fill: Color, ink: Color) {
        Self.palette[TagName.tintIndex(for: name, paletteCount: Self.palette.count)]
    }

    public var body: some View {
        Text(name)
            .font(size.font)
            .foregroundStyle(colors.ink)
            .lineLimit(1)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(colors.fill, in: Capsule())
    }
}

/// Tags laid out left to right, wrapping onto new lines. A plain `HStack` would
/// push a long catalog off the edge, and a horizontal `ScrollView` hides tags
/// the user needs to see to pick from.
public struct TagFlow<Content: View>: View {
    private let names: [String]
    private let content: (String) -> Content

    public init(_ names: [String], @ViewBuilder content: @escaping (String) -> Content) {
        self.names = names
        self.content = content
    }

    public var body: some View {
        WrappingLayout(spacing: 6, lineSpacing: 6) {
            ForEach(names, id: \.self, content: content)
        }
    }
}

struct WrappingLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var total = CGSize.zero

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth > 0, lineWidth + spacing + size.width > maxWidth {
                total.width = max(total.width, lineWidth)
                total.height += lineHeight + lineSpacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += lineWidth > 0 ? spacing + size.width : size.width
                lineHeight = max(lineHeight, size.height)
            }
        }
        total.width = max(total.width, lineWidth)
        total.height += lineHeight
        return total
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// A meal's tags on a surface too small for all of them: shows what fits and
/// counts the rest.
public struct TagChipRow: View {
    private let tags: [String]
    private let limit: Int
    private let size: TagChip.Size

    public init(_ tags: [String], limit: Int = 3, size: TagChip.Size = .small) {
        self.tags = tags
        self.limit = limit
        self.size = size
    }

    public var body: some View {
        let shown = tags.prefix(limit)
        let hidden = tags.count - shown.count
        HStack(spacing: 4) {
            ForEach(Array(shown), id: \.self) { TagChip($0, size: size) }
            if hidden > 0 {
                Text(verbatim: "+\(hidden)")
                    .font(size.font)
                    .foregroundStyle(.appMuted)
            }
        }
    }
}
