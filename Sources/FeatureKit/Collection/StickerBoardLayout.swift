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

    /// How this board arranges itself on a recap card. Each board has a character
    /// on screen, and a recap that ignored it looked like the same card four times.
    var recapStyle: RecapCollageStyle {
        switch self {
        // Playful and scattered, like stickers stuck on in a hurry.
        case .strawberryCheck:
            return RecapCollageStyle(
                tiltScale: 1.2, sizeScale: 1, waveAmplitude: 0.02, surfaceTilt: -1.1
            )
        // A diary: straight rows, barely a tilt.
        case .creamDiary:
            return RecapCollageStyle(
                tiltScale: 0.25, sizeScale: 0.94, waveAmplitude: 0, surfaceTilt: 0
            )
        // Pop: bigger, bolder, leaning hard.
        case .lavenderPop:
            return RecapCollageStyle(
                tiltScale: 1.8, sizeScale: 1.1, waveAmplitude: 0.045, surfaceTilt: -2.4
            )
        // Soda: everything drifting on a gentle wave.
        case .sodaBlue:
            return RecapCollageStyle(
                tiltScale: 0.8, sizeScale: 0.97, waveAmplitude: 0.07, surfaceTilt: 1.4
            )
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

/// The knobs a board turns on its recap card.
struct RecapCollageStyle: Equatable {
    /// Multiplier on each sticker's tilt.
    let tiltScale: Double
    /// Multiplier on each sticker's size.
    let sizeScale: CGFloat
    /// Height of the wave the columns ride, as a fraction of the canvas.
    let waveAmplitude: CGFloat
    /// The board card's own rotation, in degrees.
    let surfaceTilt: Double

    /// Where a sticker in `column` sits on the wave.
    func waveOffset(column: Int, canvasHeight: CGFloat) -> CGFloat {
        guard waveAmplitude > 0 else { return 0 }
        let phase = Double(column) * .pi / 2
        return canvasHeight * waveAmplitude * CGFloat(sin(phase))
    }
}

struct StickerBoardSurface: View {
    let theme: StickerBoardTheme
    var borderOpacity: Double = 0.30

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
    }

    var body: some View {
        StickerBoardThemeBackground(theme: theme)
            .clipShape(shape)
            .overlay {
                shape
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
                // Sized from the space given rather than fixed: at 190pt these
                // blobs were larger than a swatch in the style sheet and pushed
                // its layout apart.
                GeometryReader { proxy in
                    let blob = min(proxy.size.width, proxy.size.height)
                    ZStack {
                        Circle()
                            .fill(Color.appPink.opacity(0.25))
                            .frame(width: blob * 0.55, height: blob * 0.55)
                            .position(x: proxy.size.width * 0.86, y: proxy.size.height * 0.1)
                        Circle()
                            .fill(Color.appBlue.opacity(0.18))
                            .frame(width: blob * 0.46, height: blob * 0.46)
                            .position(x: proxy.size.width * 0.08, y: proxy.size.height * 0.9)
                    }
                }
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

    /// Where the drop zone sits while a sticker is being carried: bottom centre,
    /// above the floating tab bar.
    static func removeZoneCenter(width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(x: width / 2, y: height - 132)
    }

    /// Radius counted as "over the zone". Generous, because a sticker is dropped
    /// with a fingertip covering it.
    static let removeZoneRadius: CGFloat = 62

    /// Whether a sticker dropped at `point` lands on the zone.
    static func isOverRemoveZone(_ point: CGPoint, width: CGFloat, height: CGFloat) -> Bool {
        let centre = removeZoneCenter(width: width, height: height)
        return hypot(point.x - centre.x, point.y - centre.y) <= removeZoneRadius
    }

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

    /// Where the corner handle sits for a sticker at this scale and rotation.
    ///
    /// The handle lives at the sticker's bottom-trailing corner, which is 45° out
    /// from centre in the sticker's own unrotated frame.
    /// Shortest way round from one angle to another, in degrees (-180...180).
    ///
    /// Needed because a handle swung past due-west jumps from 179° to -179°;
    /// subtracting raw angles would spin the sticker a full turn.
    /// Scale after the handle has moved from `grabDistance` to `distance`.
    ///
    /// Relative to where the finger landed, not to the corner: grabbing the
    /// handle slightly off-centre must not resize the sticker before it moves.
    /// Angle of `point` measured from `center`, in degrees.
    /// Distance between two points, floored so a grab at the exact centre cannot
    /// divide by zero.
    /// Where to drop a sticker being put back on the board from the drawer.
    ///
    /// Walks the default grid slots and takes the first one that is not already
    /// under another sticker, the way a desktop drops a new icon into the next
    /// free space rather than on top of one.
    static func firstFreeSlot(
        occupied: [CGPoint],
        width: CGFloat,
        height: CGFloat,
        topInset: CGFloat = 0
    ) -> CGPoint {
        let side = itemSide(width: width)
        let clearance = side * 0.75
        // Bounded so a board packed solid still returns promptly.
        let slots = max(columns, Int((height / max(side * 0.92, 1)).rounded(.up)) * columns) + columns
        for index in 0..<slots {
            let candidate = defaultPoint(index: index, width: width, topInset: topInset)
            guard candidate.y <= height else { break }
            let isClear = occupied.allSatisfy {
                hypot(candidate.x - $0.x, candidate.y - $0.y) > clearance
            }
            if isClear { return candidate }
        }
        // Nothing free: land it in the middle rather than off the canvas.
        return clamped(
            CGPoint(x: width / 2, y: min(topInset + side, height / 2)),
            width: width,
            height: height
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
