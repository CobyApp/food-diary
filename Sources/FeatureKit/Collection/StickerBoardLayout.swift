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

enum StickerBoardFrame: String, CaseIterable, Codable, Identifiable {
    case softPaper
    case cloud
    case scallop
    case ticket

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .softPaper: return "board.shape.soft"
        case .cloud: return "board.shape.cloud"
        case .scallop: return "board.shape.scallop"
        case .ticket: return "board.shape.ticket"
        }
    }

    var shape: AnyShape {
        switch self {
        case .softPaper:
            return AnyShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        case .cloud:
            return AnyShape(CloudBoardShape())
        case .scallop:
            return AnyShape(ScallopedBoardShape())
        case .ticket:
            return AnyShape(TicketBoardShape())
        }
    }
}

struct StickerBoardSurface: View {
    let theme: StickerBoardTheme
    let frame: StickerBoardFrame
    var borderOpacity: Double = 0.30

    var body: some View {
        StickerBoardThemeBackground(theme: theme)
            .clipShape(frame.shape)
            .overlay {
                frame.shape
                    .stroke(
                        theme.accent.opacity(borderOpacity),
                        style: StrokeStyle(lineWidth: 1.7, dash: [7, 7])
                    )
            }
    }
}

struct StickerBoardThemeBackground: View {
    let theme: StickerBoardTheme

    var body: some View {
        ZStack {
            theme.base
            pattern
            // Behind a Color.clear overlay on purpose: a bare scaledToFill image
            // reports its own oversized dimensions as an ideal size, which used to
            // be harmless inside the board card's fixed frame but pushes a
            // full-screen layout wider than the screen.
            Color.clear
                .overlay {
                    Image("StickerPaper")
                        .resizable()
                        .scaledToFill()
                }
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

private struct CloudBoardShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.07, y: h * 0.12))
        path.addCurve(
            to: CGPoint(x: w * 0.31, y: h * 0.055),
            control1: CGPoint(x: w * 0.08, y: h * 0.045),
            control2: CGPoint(x: w * 0.20, y: h * 0.035)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.58, y: h * 0.045),
            control1: CGPoint(x: w * 0.38, y: -h * 0.01),
            control2: CGPoint(x: w * 0.51, y: -h * 0.005)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.84, y: h * 0.10),
            control1: CGPoint(x: w * 0.68, y: h * 0.005),
            control2: CGPoint(x: w * 0.80, y: h * 0.035)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.96, y: h * 0.20),
            control1: CGPoint(x: w * 0.94, y: h * 0.07),
            control2: CGPoint(x: w * 0.98, y: h * 0.13)
        )
        path.addLine(to: CGPoint(x: w * 0.98, y: h * 0.84))
        path.addCurve(
            to: CGPoint(x: w * 0.79, y: h * 0.95),
            control1: CGPoint(x: w, y: h * 0.93),
            control2: CGPoint(x: w * 0.91, y: h * 0.98)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.48, y: h * 0.96),
            control1: CGPoint(x: w * 0.71, y: h * 1.01),
            control2: CGPoint(x: w * 0.57, y: h * 1.01)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.17, y: h * 0.94),
            control1: CGPoint(x: w * 0.38, y: h * 1.01),
            control2: CGPoint(x: w * 0.24, y: h)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.03, y: h * 0.82),
            control1: CGPoint(x: w * 0.06, y: h * 0.97),
            control2: CGPoint(x: w, y: h * 0.91)
        )
        path.addLine(to: CGPoint(x: w * 0.025, y: h * 0.22))
        path.addCurve(
            to: CGPoint(x: w * 0.07, y: h * 0.12),
            control1: CGPoint(x: -w * 0.005, y: h * 0.17),
            control2: CGPoint(x: w * 0.015, y: h * 0.12)
        )
        path.closeSubpath()
        return path
    }
}

private struct ScallopedBoardShape: Shape {
    func path(in rect: CGRect) -> Path {
        let steps = max(Int(rect.width / 7), 36)
        let inset: CGFloat = 5
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + inset))

        for index in 0...steps {
            let progress = CGFloat(index) / CGFloat(steps)
            let wave = (1 + cos(progress * .pi * CGFloat(steps / 2))) * inset / 2
            path.addLine(to: CGPoint(
                x: rect.minX + progress * rect.width,
                y: rect.minY + wave
            ))
        }
        for index in 0...steps {
            let progress = CGFloat(index) / CGFloat(steps)
            let wave = (1 + cos(progress * .pi * CGFloat(steps / 2))) * inset / 2
            path.addLine(to: CGPoint(
                x: rect.maxX - wave,
                y: rect.minY + progress * rect.height
            ))
        }
        for index in 0...steps {
            let progress = CGFloat(index) / CGFloat(steps)
            let wave = (1 + cos(progress * .pi * CGFloat(steps / 2))) * inset / 2
            path.addLine(to: CGPoint(
                x: rect.maxX - progress * rect.width,
                y: rect.maxY - wave
            ))
        }
        for index in 0...steps {
            let progress = CGFloat(index) / CGFloat(steps)
            let wave = (1 + cos(progress * .pi * CGFloat(steps / 2))) * inset / 2
            path.addLine(to: CGPoint(
                x: rect.minX + wave,
                y: rect.maxY - progress * rect.height
            ))
        }
        path.closeSubpath()
        return path
    }
}

private struct TicketBoardShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 24
        let notch: CGFloat = 14
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - notch))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY + notch),
            control: CGPoint(x: rect.maxX - notch * 1.35, y: rect.midY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - r, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - r),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + notch))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.midY - notch),
            control: CGPoint(x: rect.minX + notch * 1.35, y: rect.midY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
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

    /// - Parameter topInset: height of the controls floating over the board, so a
    ///   sticker that has never been moved lands clear of them. Dragging is not
    ///   restricted by it — `clamped` still allows the full canvas.
    static func defaultPoint(index: Int, width: CGFloat, topInset: CGFloat = 0) -> CGPoint {
        let side = itemSide(width: width)
        let columnWidth = width / CGFloat(columns)
        let column = index % columns
        let row = index / columns
        return CGPoint(
            x: columnWidth * (CGFloat(column) + 0.5),
            y: topInset + verticalInset + side / 2 + CGFloat(row) * (side * 0.92)
        )
    }

    /// - Parameter minimum: floor for the canvas, so a nearly empty board still
    ///   fills the screen and leaves somewhere to drag a sticker to.
    static func boardHeight(
        count: Int,
        width: CGFloat,
        placements: [StickerBoardPlacement],
        topInset: CGFloat = 0,
        minimum: CGFloat = minimumHeight
    ) -> CGFloat {
        let side = itemSide(width: width)
        let lastDefaultY = count > 0
            ? defaultPoint(index: count - 1, width: width, topInset: topInset).y
            : 0
        let lastPlacedEdge = placements.map {
            CGFloat($0.y) + side * $0.displayScale / 2
        }.max() ?? 0
        return max(
            minimum,
            max(lastDefaultY + side / 2, lastPlacedEdge) + verticalInset
        )
    }

    static func point(
        for placement: StickerBoardPlacement?,
        index: Int,
        width: CGFloat,
        height: CGFloat,
        topInset: CGFloat = 0
    ) -> CGPoint {
        guard let placement else {
            return defaultPoint(index: index, width: width, topInset: topInset)
        }
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

    static func snappedScale(_ value: Double) -> Double {
        let value = clampedScale(value)
        return abs(value - 1) <= 0.045 ? 1 : value
    }

    static func normalizedRotation(_ degrees: Double) -> Double {
        var value = degrees.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value < -180 { value += 360 }
        return value
    }

    static func snappedRotation(_ degrees: Double) -> Double {
        let value = normalizedRotation(degrees)
        let nearestStep = (value / 15).rounded() * 15
        return abs(value - nearestStep) <= 2.2 ? nearestStep : value
    }
}
