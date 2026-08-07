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


// MARK: - Board styles

/// The four boards, so the listing shows the app can be dressed up.
struct StoreThemeScene: View {
    let food: StoreSampleFood

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
            spacing: 14
        ) {
            ForEach(Array(StickerBoardTheme.allCases.enumerated()), id: \.element.id) { index, theme in
                VStack(spacing: 8) {
                    StickerBoardThemeBackground(theme: theme)
                        .frame(height: 172)
                        .overlay {
                            StickerTile(tint: .rotating(index)) {
                                CutoutImage(image: food.image)
                            }
                            .frame(width: 106, height: 106)
                            .rotationEffect(.degrees(-4))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(theme.accent.opacity(0.55), lineWidth: 2)
                        }

                    Text(L10n.text(theme.titleKey))
                        .font(.appSection)
                        .foregroundStyle(.appInk)
                        .lineLimit(1)
                }
            }
        }
        .frame(height: 430, alignment: .top)
    }
}

// MARK: - Map

/// Where each meal happened. The real screen is a live MapKit view, which cannot
/// render offline, so the pins sit on the app's own paper instead of a live map.
struct StoreMapScene: View {
    let foods: [StoreSampleFood]
    let place: String

    private let spots: [(CGFloat, CGFloat)] = [
        (0.26, 0.22), (0.68, 0.17), (0.48, 0.44), (0.22, 0.66), (0.74, 0.63),
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // A quiet street grid, so the pins read as being on a map.
                // Wide white roads over a block colour, then thin lines on top:
                // a grid alone reads as graph paper rather than a map.
                StoreMapGrid()
                    .stroke(Color.appCard, lineWidth: 13)
                StoreMapGrid()
                    .stroke(Color.appBlueInk.opacity(0.14), lineWidth: 1.5)

                ForEach(Array(foods.prefix(5).enumerated()), id: \.element.id) { index, food in
                    let spot = spots[index % spots.count]
                    StoreMapPin(food: food, isSelected: index == 2)
                        .position(
                            x: proxy.size.width * spot.0,
                            y: proxy.size.height * spot.1
                        )
                }
            }
        }
        .background(Color(hex: 0xDCE6DD))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(alignment: .bottom) {
            SoftCard {
                HStack(spacing: 10) {
                    StickerTile(tint: .pink) { CutoutImage(image: foods[2].image) }
                        .frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(place)
                            .font(.appSection)
                            .foregroundStyle(.appInk)
                        StarRating(rating: 5)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(10)
        }
        .frame(height: 430)
    }
}

private struct StoreMapPin: View {
    let food: StoreSampleFood
    let isSelected: Bool

    var body: some View {
        StickerTile(tint: isSelected ? .pink : .blue) {
            CutoutImage(image: food.image)
        }
        .frame(width: isSelected ? 96 : 74, height: isSelected ? 96 : 74)
        .background(
            Circle()
                .fill(Color.appCard)
                .padding(-5)
        )
        .overlay(alignment: .bottom) {
            Triangle()
                .fill(Color.appCard)
                .frame(width: 16, height: 12)
                .offset(y: 11)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct StoreMapGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for x in stride(from: rect.minX, through: rect.maxX, by: 62) {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x + 18, y: rect.maxY))
        }
        for y in stride(from: rect.minY, through: rect.maxY, by: 58) {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y - 12))
        }
        return path
    }
}

// MARK: - The game

/// Two dishes, one pick — the world cup round, laid out like `WorldCupView`.
struct StoreGameScene: View {
    let foods: [StoreSampleFood]
    let prompt: String
    let places: [String]

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text(verbatim: "FOOD TASTE MATCH")
                    .font(.appCaption)
                    .tracking(1.6)
                    .foregroundStyle(.appPinkInk)
                Text(L10n.format("round.count", 8))
                    .font(.appDisplay)
                    .foregroundStyle(.appInk)
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < 1 ? Color.appCherry : Color.appCherry.opacity(0.25))
                            .frame(width: 7, height: 7)
                    }
                }
            }

            HStack(spacing: 10) {
                contender(foods[0], index: 0)
                Text(verbatim: "VS")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.appCard)
                    .frame(width: 46, height: 46)
                    .background(Color.appCherry, in: Circle())
                    .overlay { Circle().stroke(Color.appCard, lineWidth: 3) }
                    .zIndex(2)
                contender(foods[1], index: 1)
            }

            Text(prompt)
                .font(.appCaption)
                .foregroundStyle(.appMuted)
        }
    }

    private func contender(_ food: StoreSampleFood, index: Int) -> some View {
        VStack(spacing: 10) {
            StickerTile(tint: .rotating(index)) {
                CutoutImage(image: food.image)
            }
            .frame(width: 142, height: 200)
            Text(places[index % places.count])
                .font(.appCaption)
                .foregroundStyle(.appChocolate)
                .lineLimit(1)
        }
        .padding(8)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.appChocolate.opacity(0.14), lineWidth: 1.5)
        }
        .rotationEffect(.degrees(index == 0 ? -1.5 : 1.5))
        .softShadow()
    }
}

/// Deciding together: everyone votes, the majority wins.
struct StoreGroupScene: View {
    let foods: [StoreSampleFood]
    let rules: [String]
    let votingLabel: String

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(rules, id: \.self) { rule in
                    Text(rule)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.appChocolate)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appButter, in: Capsule())
                }
            }

            HStack(spacing: 10) {
                ForEach(Array(foods.prefix(2).enumerated()), id: \.element.id) { index, food in
                    VStack(spacing: 8) {
                        StickerTile(tint: .rotating(index)) {
                            CutoutImage(image: food.image)
                        }
                        .frame(height: 185)

                        // Two of three voted for the left dish.
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { slot in
                                Circle()
                                    .fill(
                                        slot < (index == 0 ? 2 : 1)
                                            ? Color.appCherry
                                            : Color.appChocolate.opacity(0.16)
                                    )
                                    .frame(width: 13, height: 13)
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        Color.appCard.opacity(index == 0 ? 0.95 : 0.6),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                }
            }

            Text(votingLabel)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.appBlueInk, in: Capsule())
        }
    }
}

// MARK: - Achievements

/// The streak and the badge book, so the listing shows there is something to keep.
struct StoreAchievementScene: View {
    let streakLabel: String
    let badges: [(symbol: String, title: String, unlocked: Bool)]

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(Color.appCherry)
                Text(streakLabel)
                    .font(.appSection)
                    .foregroundStyle(.appInk)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.appCard, in: Capsule())
            .softShadow()

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                spacing: 14
            ) {
                ForEach(badges, id: \.title) { badge in
                    SoftCard {
                        VStack(spacing: 9) {
                            KitschIcon(
                                badge.symbol,
                                tint: badge.unlocked ? .appChocolate : .appMuted,
                                background: badge.unlocked ? .appButter : .appTileBlue,
                                size: 68
                            )
                            .opacity(badge.unlocked ? 1 : 0.5)
                            .overlay(alignment: .bottomTrailing) {
                                if !badge.unlocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 13, weight: .black))
                                        .foregroundStyle(Color.appMuted)
                                        .padding(4)
                                        .background(Color.appCard, in: Circle())
                                        .offset(x: 4, y: 4)
                                }
                            }

                            Text(badge.title)
                                .font(.appSection)
                                // Muted, not faint: a locked badge still has to be
                                // legible in a store thumbnail.
                                .foregroundStyle(
                                    badge.unlocked
                                        ? Color.appInk
                                        : Color.appChocolate.opacity(0.55)
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}
