import SwiftUI

/// The shareable weekly recap in Instagram Story format.
///
/// 360×640 pt rendered at scale 3 becomes exactly 1080×1920 px.
struct RecapStoryCard: View {
    let images: [UIImage]
    let mealCount: Int
    let rangeText: String
    var caption: String?

    static let size = CGSize(width: 360, height: 640)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            scrapbookCollage
                .frame(height: 352)
                .padding(.top, 7)
            captionNote
                .padding(.top, 7)
            footer
                .padding(.top, 10)
        }
        .padding(.horizontal, 22)
        .padding(.top, 28)
        .padding(.bottom, 22)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(background)
        .overlay {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.appChocolate.opacity(0.10), lineWidth: 1)
                .padding(9)
        }
        .overlay(alignment: .topLeading) {
            WashiTape(.appButter)
                .rotationEffect(.degrees(-12))
                .offset(x: -15, y: 13)
        }
        .overlay(alignment: .topTrailing) {
            StoryBow()
                .frame(width: 55, height: 44)
                .rotationEffect(.degrees(8))
                .offset(x: -11, y: 12)
        }
        .overlay(alignment: .bottomLeading) {
            StoryCheckerPattern(color: .appCherry.opacity(0.72), cellSize: 9)
                .frame(width: 86, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .rotationEffect(.degrees(7))
                .offset(x: -12, y: -7)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.text("recap.story.kicker"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.7)
                    .foregroundStyle(.appPinkInk)
                Spacer()
                Text(rangeText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.appMuted)
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(L10n.text("이번 주 한 끼"))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.appInk)
                    .shadow(color: Color.appPink.opacity(0.85), radius: 0, x: 2, y: 2)
                    .minimumScaleFactor(0.78)
                    .lineLimit(1)
                Text(L10n.format("recap.story.count", mealCount))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.appChocolate)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.appButter, in: Capsule())
                    .rotationEffect(.degrees(2))
            }
        }
    }

    private var scrapbookCollage: some View {
        GeometryReader { proxy in
            let count = min(images.count, 9)
            ZStack {
                StoryCheckerPattern(color: .appPinkInk.opacity(0.18), cellSize: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .padding(5)
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.appCard.opacity(0.58))
                    .frame(width: proxy.size.width - 10, height: proxy.size.height - 18)
                    .rotationEffect(.degrees(-1.1))
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(
                        Color.appChocolate.opacity(0.12),
                        style: StrokeStyle(lineWidth: 1.2, dash: [6, 6])
                    )
                    .frame(width: proxy.size.width - 14, height: proxy.size.height - 22)
                    .rotationEffect(.degrees(-1.1))

                ForEach(Array(images.prefix(9).enumerated()), id: \.offset) { index, image in
                    let placement = placement(
                        index: index,
                        count: count,
                        canvas: proxy.size
                    )
                    StickerTile(tint: .rotating(index)) {
                        CutoutImage(image: image)
                    }
                    .frame(width: placement.side, height: placement.side)
                    .rotationEffect(.degrees(placement.rotation))
                    .position(placement.center)
                    .zIndex(Double(index + 1))
                }

                KitschSparkle()
                    .fill(Color.appCherry.opacity(0.76))
                    .frame(width: 20, height: 20)
                    .position(x: 31, y: 53)
                Circle()
                    .stroke(Color.appBlueInk.opacity(0.36), lineWidth: 3)
                    .frame(width: 29, height: 29)
                    .position(x: proxy.size.width - 31, y: proxy.size.height - 48)
                StoryDoodle()
                    .stroke(
                        Color.appButterInk.opacity(0.45),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                    )
                    .frame(width: 46, height: 25)
                    .rotationEffect(.degrees(-8))
                    .position(x: 49, y: proxy.size.height - 34)

                Text(L10n.text("recap.story.sticker"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.appCherry, in: Capsule())
                    .overlay(Capsule().stroke(Color.appCard, lineWidth: 2))
                    .rotationEffect(.degrees(7))
                    .position(x: proxy.size.width - 58, y: 31)
                    .zIndex(20)

                StoryHeart()
                    .fill(Color.appPinkInk.opacity(0.82))
                    .frame(width: 22, height: 20)
                    .rotationEffect(.degrees(-12))
                    .position(x: proxy.size.width - 28, y: proxy.size.height - 34)
                    .zIndex(20)
            }
        }
    }

    private var captionNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Text("“")
                .font(.system(size: 30, weight: .black, design: .serif))
                .foregroundStyle(.appPinkInk)
                .offset(y: -5)
            Text(displayCaption)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.appInk)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
            KitschSparkle()
                .fill(Color.appButterInk)
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            ZStack {
                Color.appCard.opacity(0.96)
                StoryCheckerPattern(color: .appPink.opacity(0.18), cellSize: 11)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appPink.opacity(0.78), lineWidth: 1.5)
        }
        .rotationEffect(.degrees(-0.7))
    }

    private var displayCaption: String {
        let line = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return line.isEmpty ? L10n.text("맛있게 잘 먹었다") : line
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 5) {
                KitschSparkle()
                    .fill(Color.appButter)
                    .frame(width: 11, height: 11)
                Text(L10n.text("얌키"))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.appChocolate)
            }
            Spacer()
            Text(verbatim: "@yumkie · WEEKLY FOOD NOTE")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.appMuted)
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.appMilk,
                    Color.appTilePink.opacity(0.92),
                    Color.appTileButter.opacity(0.72),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.appBlue.opacity(0.18))
                .frame(width: 190, height: 190)
                .offset(x: 170, y: -250)
                .blur(radius: 2)
            Circle()
                .fill(Color.appPink.opacity(0.20))
                .frame(width: 180, height: 180)
                .offset(x: -170, y: 276)
                .blur(radius: 3)
            StoryDotPattern()
                .foregroundStyle(Color.appChocolate.opacity(0.08))
            Image("StickerPaper")
                .resizable()
                .scaledToFill()
                .opacity(0.28)
                .blendMode(.multiply)
        }
        .clipped()
    }

    private func placement(
        index: Int,
        count: Int,
        canvas: CGSize
    ) -> (center: CGPoint, side: CGFloat, rotation: Double) {
        let rotations = [-5.0, 4.0, -1.5, 5.5, -4.0, 2.5, -3.0, 4.5, -1.0]
        let specs: [(CGFloat, CGFloat, CGFloat)]
        switch count {
        case 0:
            specs = []
        case 1:
            specs = [(0.50, 0.51, 244)]
        case 2:
            specs = [(0.37, 0.34, 194), (0.65, 0.68, 194)]
        case 3:
            specs = [(0.31, 0.29, 164), (0.70, 0.35, 160), (0.49, 0.72, 168)]
        case 4:
            specs = [
                (0.29, 0.28, 146), (0.70, 0.30, 148),
                (0.31, 0.70, 148), (0.72, 0.71, 144),
            ]
        case 5:
            specs = [
                (0.27, 0.25, 132), (0.70, 0.25, 130),
                (0.49, 0.51, 138), (0.25, 0.76, 130), (0.72, 0.75, 132),
            ]
        case 6:
            specs = [
                (0.24, 0.24, 120), (0.52, 0.25, 120), (0.78, 0.28, 116),
                (0.23, 0.72, 118), (0.52, 0.70, 122), (0.78, 0.73, 118),
            ]
        default:
            specs = [
                (0.20, 0.20, 104), (0.50, 0.19, 106), (0.80, 0.22, 102),
                (0.20, 0.50, 106), (0.50, 0.49, 108), (0.80, 0.51, 104),
                (0.20, 0.80, 102), (0.50, 0.79, 106), (0.80, 0.80, 104),
            ]
        }
        let spec = specs[min(index, specs.count - 1)]
        return (
            CGPoint(x: canvas.width * spec.0, y: canvas.height * spec.1),
            spec.2,
            rotations[index % rotations.count]
        )
    }
}

private struct StoryCheckerPattern: View {
    let color: Color
    let cellSize: CGFloat

    var body: some View {
        Canvas { context, size in
            let columns = Int(ceil(size.width / cellSize))
            let rows = Int(ceil(size.height / cellSize))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    context.fill(
                        Path(CGRect(
                            x: CGFloat(column) * cellSize,
                            y: CGFloat(row) * cellSize,
                            width: cellSize,
                            height: cellSize
                        )),
                        with: .color(color)
                    )
                }
            }
        }
    }
}

private struct StoryBow: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.appCherry)
                .frame(width: 34, height: 24)
                .rotationEffect(.degrees(28))
                .offset(x: -14)
            Capsule()
                .fill(Color.appCherry)
                .frame(width: 34, height: 24)
                .rotationEffect(.degrees(-28))
                .offset(x: 14)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.appPinkInk)
                .frame(width: 11, height: 24)
                .rotationEffect(.degrees(18))
                .offset(x: -5, y: 14)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.appPinkInk)
                .frame(width: 11, height: 24)
                .rotationEffect(.degrees(-18))
                .offset(x: 5, y: 14)
            Circle()
                .fill(Color.appButter)
                .frame(width: 17, height: 17)
                .overlay(Circle().stroke(Color.appCard, lineWidth: 2))
        }
        .shadow(color: Color.appChocolate.opacity(0.20), radius: 2, y: 2)
    }
}

private struct StoryHeart: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.height * 0.32),
            control1: CGPoint(x: rect.width * 0.18, y: rect.height * 0.76),
            control2: CGPoint(x: rect.minX, y: rect.height * 0.54)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.height * 0.30),
            control1: CGPoint(x: rect.minX, y: rect.height * 0.05),
            control2: CGPoint(x: rect.width * 0.34, y: rect.height * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.32),
            control1: CGPoint(x: rect.width * 0.66, y: rect.height * 0.02),
            control2: CGPoint(x: rect.maxX, y: rect.height * 0.05)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.height * 0.54),
            control2: CGPoint(x: rect.width * 0.82, y: rect.height * 0.76)
        )
        return path
    }
}

private struct StoryDotPattern: View {
    var body: some View {
        Canvas { context, size in
            for y in stride(from: 18.0, through: size.height, by: 34) {
                for x in stride(from: 18.0, through: size.width, by: 34) {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 2.6, height: 2.6)),
                        with: .foreground
                    )
                }
            }
        }
    }
}

private struct StoryDoodle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.width * 0.25, y: rect.minY),
            control2: CGPoint(x: rect.width * 0.70, y: rect.maxY)
        )
        return path
    }
}
