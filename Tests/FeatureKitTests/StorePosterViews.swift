import SwiftUI
@testable import FeatureKit

/// One store screenshot: headline at the top, a piece of the app below it.
///
/// A poster rather than a raw screen capture. The store shows these at thumbnail
/// size first, where a bare screenshot reads as noise; a line of text and one
/// clear thing to look at survive being shrunk.
struct StorePoster<Content: View>: View {
    let headline: StoreCopy.Headline
    let theme: StickerBoardTheme
    /// Whether the content sits on a plate. Off for content that is already a
    /// card of its own — a card inside a card reads as clutter.
    var plated: Bool = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            StickerBoardThemeBackground(theme: theme)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(headline.title)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.appInk)
                        .shadow(color: theme.secondary.opacity(0.9), radius: 0, x: 2, y: 2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(headline.subtitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.appChocolate)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 34)
                .padding(.top, 68)

                Spacer(minLength: 18)

                if plated {
                    // An opaque plate, so app content reads as the app rather than
                    // dissolving into the patterned backdrop behind it.
                    content()
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(
                            Color.appMilk,
                            in: RoundedRectangle(cornerRadius: 40, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 40, style: .continuous)
                                .stroke(Color.appCard, lineWidth: 4)
                        }
                        .padding(.horizontal, 22)
                        .shadow(color: Color.appChocolate.opacity(0.18), radius: 20, y: 12)
                } else {
                    content()
                        .shadow(color: Color.appChocolate.opacity(0.2), radius: 22, y: 12)
                }

                Spacer(minLength: 34)
            }
        }
    }
}

// MARK: - Scenes

/// The board: stickers scattered the way a real one looks.
struct StoreBoardScene: View {
    let foods: [StoreSampleFood]

    private let spots: [(CGFloat, CGFloat, Double)] = [
        (0.26, 0.15, -6), (0.72, 0.20, 5), (0.49, 0.45, -2),
        (0.24, 0.70, 4), (0.75, 0.74, -5), (0.49, 0.90, 3),
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(foods.prefix(6).enumerated()), id: \.element.id) { index, food in
                    let spot = spots[index % spots.count]
                    StickerTile(tint: .rotating(index)) {
                        CutoutImage(image: food.image)
                    }
                    .frame(width: 138, height: 138)
                    .rotationEffect(.degrees(spot.2))
                    .position(
                        x: proxy.size.width * spot.0,
                        y: proxy.size.height * spot.1
                    )
                }
            }
        }
        .frame(height: 520)
    }
}

/// Choosing which cutouts to keep, the way the capture step looks.
struct StoreCutoutScene: View {
    let foods: [StoreSampleFood]

    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(Array(foods.prefix(4).enumerated()), id: \.element.id) { index, food in
                    StickerTile(tint: .rotating(index)) {
                        CutoutImage(image: food.image)
                    }
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: index == 3 ? "circle" : "checkmark.circle.fill")
                            .font(.title2.bold())
                            .foregroundStyle(index == 3 ? Color.appMuted : Color.appBlue)
                            .padding(7)
                    }
                    .opacity(index == 3 ? 0.5 : 1)
                }
            }

            Label(L10n.format("capture.next.selected", 3), systemImage: "arrow.right")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.appCherry, in: Capsule())
        }
        .frame(height: 430)
    }
}

/// One food being described: its own tags and rating.
struct StoreTagScene: View {
    let food: StoreSampleFood
    let tags: [String]

    var body: some View {
        VStack(spacing: 16) {
            StickerTile(tint: .pink) {
                CutoutImage(image: food.image)
            }
            .frame(width: 190, height: 190)

            SoftCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("태그"))
                        .font(.appSection)
                        .foregroundStyle(.appInk)
                    TagFlow(tags) { TagChip($0) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            SoftCard {
                HStack {
                    Text(L10n.text("별점")).font(.appSection).foregroundStyle(.appInk)
                    Spacer()
                    StarRating(rating: 5)
                }
            }
        }
        .frame(height: 430)
    }
}

/// The drawer: everything saved, with what each food was.
struct StoreDrawerScene: View {
    let foods: [StoreSampleFood]
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.format("drawer.count", 4, 6))
                .font(.appCaption)
                .foregroundStyle(.appMuted)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(Array(foods.prefix(6).enumerated()), id: \.element.id) { index, food in
                    VStack(spacing: 6) {
                        StickerTile(tint: .rotating(index)) {
                            CutoutImage(image: food.image)
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .opacity(index < 4 ? 1 : 0.45)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: index < 4 ? "checkmark.circle.fill" : "plus.circle")
                                .font(.body.bold())
                                .foregroundStyle(index < 4 ? Color.appCherry : Color.appMuted)
                                .padding(4)
                        }

                        TagChip(tags[index % tags.count], size: .small)
                    }
                }
            }
        }
        .frame(height: 430)
    }
}
