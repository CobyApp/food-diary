import SwiftUI

/// The shareable weekly recap in Instagram Story format.
///
/// Laid out at a fixed 360×640 pt (9:16); rendered by `ImageRenderer` at
/// `scale = 3` it becomes exactly 1080×1920 px, the native Story size, so the
/// image fills the screen with no letterboxing.
struct RecapStoryCard: View {
    let images: [UIImage]
    let mealCount: Int
    let rangeText: String
    /// Apple Intelligence's line; falls back to the localized static one.
    var caption: String?

    static let size = CGSize(width: 360, height: 640)
    private static let collageTints: [StickerTint] = [.pink, .blue, .butter]

    /// Collage columns scale with how much the week holds, so a light week still
    /// looks composed instead of tiny stickers in a corner.
    private var columnCount: Int {
        switch images.count {
        case 0, 1, 2: return 1     // stack a sparse week so it still fills the canvas
        case 3, 4, 5, 6: return 2
        default: return 3
        }
    }

    /// Sized so the collage fills the canvas instead of floating in whitespace.
    private var tileHeight: CGFloat {
        switch images.count {
        case 0, 1: return 330
        case 2: return 190
        case 3, 4: return 186
        case 5, 6: return 122
        default: return 118
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 18)
            collage
            Spacer(minLength: 18)
            footer
        }
        .padding(.horizontal, 28)
        .padding(.top, 38)
        .padding(.bottom, 34)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(background)
        .overlay(alignment: .topLeading) { WashiTape(.appPink).rotationEffect(.degrees(-14)).offset(x: -18, y: 16) }
        .overlay(alignment: .topTrailing) { WashiTape(.appLavender).rotationEffect(.degrees(11)).offset(x: 20, y: 26) }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                KitschSparkle().fill(Color.appButter).frame(width: 14, height: 14)
                Text(L10n.text("얌키"))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.appChocolate)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Color.appCard.opacity(0.85), in: Capsule())

            Text(L10n.text("이번 주 한 끼"))
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(.appInk)
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            HStack(spacing: 7) {
                Text(rangeText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.appMuted)
                Text(L10n.format("recap.story.count", mealCount))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.appChocolate)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.appButter, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var collage: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(images.prefix(9).enumerated()), id: \.offset) { index, image in
                StickerTile(tint: Self.collageTints[index % Self.collageTints.count]) {
                    CutoutImage(image: image)
                }
                .frame(height: tileHeight)
                // Alternating tilt so the collage reads as pasted stickers.
                .rotationEffect(.degrees(index.isMultiple(of: 3) ? -2.2 : index.isMultiple(of: 2) ? 1.8 : 0))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(caption ?? L10n.text("맛있게 잘 먹었다"))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.appInk)
            Image(systemName: "heart.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.appCherry)
            Spacer()
            Text(verbatim: "yumkie")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.appMuted)
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appMilk, Color.appPink.opacity(0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
            // Soft blobs for depth behind the paper texture.
            Circle().fill(Color.appButter.opacity(0.26))
                .frame(width: 168, height: 168)
                .offset(x: 150, y: -252)
            Circle().fill(Color.appBlue.opacity(0.18))
                .frame(width: 140, height: 140)
                .offset(x: -150, y: 286)
            Image("StickerPaper")
                .resizable()
                .scaledToFill()
                .opacity(0.30)
                .blendMode(.multiply)
        }
        .clipped()
    }
}
