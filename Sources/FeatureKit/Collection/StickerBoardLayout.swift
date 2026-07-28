import Foundation
import SwiftUI

enum StickerBoardTheme: String, CaseIterable, Codable, Identifiable {
    case strawberryCheck
    case creamDiary
    case lavenderPop
    case sodaBlue

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .strawberryCheck: return "theme.strawberry"
        case .creamDiary: return "theme.cream"
        case .lavenderPop: return "theme.lavender"
        case .sodaBlue: return "theme.soda"
        }
    }

    var base: Color {
        switch self {
        case .strawberryCheck: return .appTilePink
        case .creamDiary: return .appMilk
        case .lavenderPop: return Color(hex: 0xF1EAFB)
        case .sodaBlue: return .appTileBlue
        }
    }

    var accent: Color {
        switch self {
        case .strawberryCheck: return .appCherry
        case .creamDiary: return .appButterInk
        case .lavenderPop: return Color(hex: 0x8B68BE)
        case .sodaBlue: return .appBlueInk
        }
    }

    var secondary: Color {
        switch self {
        case .strawberryCheck: return .appPink
        case .creamDiary: return .appButter
        case .lavenderPop: return .appLavender
        case .sodaBlue: return .appBlue
        }
    }
}

struct StickerBoardThemeBackground: View {
    let theme: StickerBoardTheme

    var body: some View {
        ZStack {
            theme.base
            pattern
            Image("StickerPaper")
                .resizable()
                .scaledToFill()
                .opacity(0.18)
                .blendMode(.multiply)
        }
        .clipped()
    }

    @ViewBuilder
    private var pattern: some View {
        switch theme {
        case .strawberryCheck:
            BoardPatternCanvas(kind: .check, color: theme.accent.opacity(0.14))
        case .creamDiary:
            BoardPatternCanvas(kind: .dot, color: theme.accent.opacity(0.16))
        case .lavenderPop:
            ZStack {
                BoardPatternCanvas(kind: .sparkle, color: theme.accent.opacity(0.14))
                Circle()
                    .fill(Color.appPink.opacity(0.25))
                    .frame(width: 190, height: 190)
                    .offset(x: 130, y: -150)
                Circle()
                    .fill(Color.appBlue.opacity(0.18))
                    .frame(width: 160, height: 160)
                    .offset(x: -150, y: 190)
            }
        case .sodaBlue:
            BoardPatternCanvas(kind: .wave, color: theme.accent.opacity(0.14))
        }
    }
}

private struct BoardPatternCanvas: View {
    enum Kind { case check, dot, sparkle, wave }

    let kind: Kind
    let color: Color

    var body: some View {
        Canvas { context, size in
            switch kind {
            case .check:
                let cell: CGFloat = 24
                for row in 0...Int(size.height / cell) {
                    for column in 0...Int(size.width / cell)
                    where (row + column).isMultiple(of: 2) {
                        context.fill(
                            Path(CGRect(
                                x: CGFloat(column) * cell,
                                y: CGFloat(row) * cell,
                                width: cell,
                                height: cell
                            )),
                            with: .color(color)
                        )
                    }
                }
            case .dot:
                for y in stride(from: 18.0, through: size.height, by: 30) {
                    for x in stride(from: 18.0, through: size.width, by: 30) {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)),
                            with: .color(color)
                        )
                    }
                }
            case .sparkle:
                for y in stride(from: 18.0, through: size.height, by: 46) {
                    for x in stride(from: 18.0, through: size.width, by: 46) {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y - 6))
                        path.addLine(to: CGPoint(x: x + 2, y: y - 2))
                        path.addLine(to: CGPoint(x: x + 6, y: y))
                        path.addLine(to: CGPoint(x: x + 2, y: y + 2))
                        path.addLine(to: CGPoint(x: x, y: y + 6))
                        path.addLine(to: CGPoint(x: x - 2, y: y + 2))
                        path.addLine(to: CGPoint(x: x - 6, y: y))
                        path.addLine(to: CGPoint(x: x - 2, y: y - 2))
                        path.closeSubpath()
                        context.fill(path, with: .color(color))
                    }
                }
            case .wave:
                for y in stride(from: 10.0, through: size.height, by: 28) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    for x in stride(from: 0.0, through: size.width, by: 24) {
                        path.addCurve(
                            to: CGPoint(x: x + 24, y: y),
                            control1: CGPoint(x: x + 6, y: y - 7),
                            control2: CGPoint(x: x + 18, y: y + 7)
                        )
                    }
                    context.stroke(path, with: .color(color), lineWidth: 2)
                }
            }
        }
    }
}

struct StickerBoardPlacement: Codable, Equatable {
    var xFraction: Double
    var y: Double
    var scale: Double?
    var rotation: Double?

    init(
        xFraction: Double,
        y: Double,
        scale: Double? = nil,
        rotation: Double? = nil
    ) {
        self.xFraction = xFraction
        self.y = y
        self.scale = scale
        self.rotation = rotation
    }

    var displayScale: CGFloat {
        CGFloat(scale ?? 1)
    }
}

enum FreeStickerBoardLayout {
    static let columns = 3
    static let minimumHeight: CGFloat = 340
    static let horizontalInset: CGFloat = 8
    static let verticalInset: CGFloat = 18
    static let scaleRange = 0.68...1.5

    static func itemSide(width: CGFloat) -> CGFloat {
        min(max((width - 24) / CGFloat(columns), 84), 118)
    }

    static func defaultPoint(index: Int, width: CGFloat) -> CGPoint {
        let side = itemSide(width: width)
        let columnWidth = width / CGFloat(columns)
        let column = index % columns
        let row = index / columns
        return CGPoint(
            x: columnWidth * (CGFloat(column) + 0.5),
            y: verticalInset + side / 2 + CGFloat(row) * (side * 0.92)
        )
    }

    static func boardHeight(count: Int, width: CGFloat, placements: [StickerBoardPlacement]) -> CGFloat {
        let side = itemSide(width: width)
        let lastDefaultY = count > 0 ? defaultPoint(index: count - 1, width: width).y : 0
        let lastPlacedEdge = placements.map {
            CGFloat($0.y) + side * $0.displayScale / 2
        }.max() ?? 0
        return max(
            minimumHeight,
            max(lastDefaultY + side / 2, lastPlacedEdge) + verticalInset
        )
    }

    static func point(
        for placement: StickerBoardPlacement?,
        index: Int,
        width: CGFloat,
        height: CGFloat
    ) -> CGPoint {
        guard let placement else { return defaultPoint(index: index, width: width) }
        return clamped(
            CGPoint(x: width * CGFloat(placement.xFraction), y: CGFloat(placement.y)),
            width: width,
            height: height,
            scale: placement.displayScale,
            rotationDegrees: placement.rotation ?? 0
        )
    }

    static func clamped(
        _ point: CGPoint,
        width: CGFloat,
        height: CGFloat,
        scale: CGFloat = 1,
        rotationDegrees: Double = 0
    ) -> CGPoint {
        let scale = min(max(scale, CGFloat(scaleRange.lowerBound)), CGFloat(scaleRange.upperBound))
        let radians = rotationDegrees * .pi / 180
        let rotatedBounds = abs(cos(radians)) + abs(sin(radians))
        let halfSide = itemSide(width: width) * scale * rotatedBounds / 2
        return CGPoint(
            x: min(max(point.x, halfSide + horizontalInset), width - halfSide - horizontalInset),
            y: min(max(point.y, halfSide + verticalInset), height - halfSide - verticalInset)
        )
    }

    static func placement(
        for point: CGPoint,
        width: CGFloat,
        height: CGFloat,
        preserving current: StickerBoardPlacement? = nil
    ) -> StickerBoardPlacement {
        let point = clamped(
            point,
            width: width,
            height: height,
            scale: current?.displayScale ?? 1,
            rotationDegrees: current?.rotation ?? 0
        )
        return StickerBoardPlacement(
            xFraction: width > 0 ? Double(point.x / width) : 0.5,
            y: Double(point.y),
            scale: current?.scale,
            rotation: current?.rotation
        )
    }

    static func defaultRotation(index: Int) -> Double {
        if index.isMultiple(of: 3) { return -2.4 }
        if index.isMultiple(of: 2) { return 2 }
        return 0.5
    }

    static func clampedScale(_ value: Double) -> Double {
        min(max(value, scaleRange.lowerBound), scaleRange.upperBound)
    }

    static func normalizedRotation(_ degrees: Double) -> Double {
        var value = degrees.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value < -180 { value += 360 }
        return value
    }
}
