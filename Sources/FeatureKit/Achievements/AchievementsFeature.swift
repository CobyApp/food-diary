import ComposableArchitecture
import Foundation
import Models
import ClientKit

public struct Achievement: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let symbol: String
    public let target: Int
    public let current: Int
    public var unlocked: Bool { current >= target }
    public var progress: Double { target == 0 ? 1 : min(1, Double(current) / Double(target)) }
}

enum AchievementMetric {
    case cutouts
    case places
    case meals
    case bestStreak
    case ratedMeals
    case fiveStarMeals
    case decoratedCutouts
}

public struct AchievementStats: Equatable, Sendable {
    public var cutouts = 0
    public var places = 0
    public var meals = 0
    public var bestStreak = 0
    public var ratedMeals = 0
    public var fiveStarMeals = 0
    public var decoratedCutouts = 0

    public init() {}
}

private struct AchievementDef {
    let id: String
    let titleKey: String
    let symbol: String
    let metric: AchievementMetric
    let target: Int
}

private func achievementSeries(
    prefix: String,
    titleKey: String,
    metric: AchievementMetric,
    targets: [Int],
    symbols: [String]
) -> [AchievementDef] {
    targets.enumerated().map { index, target in
        AchievementDef(
            id: "\(prefix)\(target)",
            titleKey: titleKey,
            symbol: symbols[min(index * symbols.count / targets.count, symbols.count - 1)],
            metric: metric,
            target: target
        )
    }
}

private let achievementCatalog: [AchievementDef] =
    achievementSeries(
        prefix: "cut",
        titleKey: "achievement.cutouts.title",
        metric: .cutouts,
        targets: [1, 3, 5, 10, 15, 20, 30, 40, 50, 75, 100, 150, 200, 300, 500],
        symbols: ["fork.knife", "seal.fill", "sparkles.rectangle.stack.fill", "star.circle.fill", "crown.fill"]
    )
    + achievementSeries(
        prefix: "meal",
        titleKey: "achievement.meals.title",
        metric: .meals,
        targets: [1, 3, 5, 10, 15, 20, 30, 40, 50, 75, 100, 150, 200, 300, 500],
        symbols: ["book.pages.fill", "books.vertical.fill", "book.closed.fill", "bookmark.fill", "trophy.fill"]
    )
    + achievementSeries(
        prefix: "plc",
        titleKey: "achievement.places.title",
        metric: .places,
        targets: [1, 3, 5, 10, 15, 20, 30, 40, 50, 75, 100, 150],
        symbols: ["mappin", "map.fill", "signpost.right.and.left.fill", "globe.asia.australia.fill"]
    )
    + achievementSeries(
        prefix: "streak",
        titleKey: "achievement.streak.title",
        metric: .bestStreak,
        targets: [2, 3, 5, 7, 10, 14, 21, 30, 50, 75, 100, 365],
        symbols: ["flame.fill", "flame.circle.fill", "bolt.heart.fill", "medal.fill"]
    )
    + achievementSeries(
        prefix: "rating",
        titleKey: "achievement.ratings.title",
        metric: .ratedMeals,
        targets: [1, 3, 5, 10, 15, 20, 30, 50, 75, 100, 200, 300],
        symbols: ["star.leadinghalf.filled", "star.square.fill", "star.bubble.fill", "star.circle.fill"]
    )
    + achievementSeries(
        prefix: "five",
        titleKey: "achievement.fiveStars.title",
        metric: .fiveStarMeals,
        targets: [1, 3, 5, 10, 15, 20, 30, 50, 75, 100, 200, 300],
        symbols: ["star.fill", "stars", "sparkles", "crown.fill"]
    )
    + achievementSeries(
        prefix: "decor",
        titleKey: "achievement.decorations.title",
        metric: .decoratedCutouts,
        targets: [1, 3, 5, 10, 20, 30, 50, 75, 100, 200, 300],
        symbols: ["paintbrush.pointed.fill", "wand.and.stars", "paintpalette.fill", "camera.filters"]
    )

func makeAchievements(stats: AchievementStats) -> [Achievement] {
    achievementCatalog.map { def in
        let current: Int
        switch def.metric {
        case .cutouts: current = stats.cutouts
        case .places: current = stats.places
        case .meals: current = stats.meals
        case .bestStreak: current = stats.bestStreak
        case .ratedMeals: current = stats.ratedMeals
        case .fiveStarMeals: current = stats.fiveStarMeals
        case .decoratedCutouts: current = stats.decoratedCutouts
        }
        return Achievement(id: def.id, title: L10n.format(def.titleKey, def.target), symbol: def.symbol,
                           target: def.target, current: current)
    }
}

@Reducer
public struct AchievementsFeature {
    @ObservableState
    public struct State: Equatable {
        public var stats = AchievementStats()
        public init() {}

        public var achievements: [Achievement] {
            makeAchievements(stats: stats)
        }
        public var unlockedCount: Int { achievements.filter(\.unlocked).count }
    }

    public enum Action: Equatable {
        case onAppear
        case statsLoaded(AchievementStats)
        case close
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [now = Date()] send in
                    // One list now: a food and its record are the same row.
                    let entries = try await persistence.allEntries()
                    var stats = AchievementStats()
                    stats.cutouts = entries.count
                    stats.meals = entries.count
                    stats.places = Set(entries.compactMap { $0.place?.id }).count
                    stats.bestStreak = MealStreak.calculate(entries: entries, now: now).best
                    stats.ratedMeals = entries.filter { $0.rating != nil }.count
                    stats.fiveStarMeals = entries.filter { $0.rating == 5 }.count
                    stats.decoratedCutouts = entries.filter {
                        guard let label = $0.label else { return false }
                        return !label.isEmpty && label != "none"
                    }.count
                    await send(.statsLoaded(stats))
                }
            case let .statsLoaded(stats):
                state.stats = stats
                return .none
            case .close:
                return .none
            }
        }
    }
}
