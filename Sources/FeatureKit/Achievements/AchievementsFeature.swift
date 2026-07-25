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
    case memoMeals
    case decoratedCutouts
}

public struct AchievementStats: Equatable, Sendable {
    public var cutouts = 0
    public var places = 0
    public var meals = 0
    public var bestStreak = 0
    public var ratedMeals = 0
    public var fiveStarMeals = 0
    public var memoMeals = 0
    public var decoratedCutouts = 0

    public init() {}
}

private struct AchievementDef {
    let id: String
    let title: String
    let symbol: String
    let metric: AchievementMetric
    let target: Int
}

private let achievementCatalog: [AchievementDef] = [
    .init(id: "cut1", title: "첫 누끼", symbol: "fork.knife", metric: .cutouts, target: 1),
    .init(id: "cut10", title: "누끼 10개", symbol: "seal.fill", metric: .cutouts, target: 10),
    .init(id: "cut30", title: "누끼 30개", symbol: "sparkles.rectangle.stack.fill", metric: .cutouts, target: 30),
    .init(id: "cut50", title: "누끼 50개", symbol: "star.circle.fill", metric: .cutouts, target: 50),
    .init(id: "cut100", title: "누끼 100개", symbol: "crown.fill", metric: .cutouts, target: 100),
    .init(id: "meal3", title: "기록 3개", symbol: "book.pages.fill", metric: .meals, target: 3),
    .init(id: "meal10", title: "기록 10개", symbol: "books.vertical.fill", metric: .meals, target: 10),
    .init(id: "meal30", title: "기록 30개", symbol: "book.closed.fill", metric: .meals, target: 30),
    .init(id: "meal100", title: "기록 100개", symbol: "trophy.fill", metric: .meals, target: 100),
    .init(id: "plc1", title: "첫 맛집", symbol: "mappin", metric: .places, target: 1),
    .init(id: "plc5", title: "맛집 5곳", symbol: "map.fill", metric: .places, target: 5),
    .init(id: "plc10", title: "맛집 10곳", symbol: "globe.asia.australia.fill", metric: .places, target: 10),
    .init(id: "plc25", title: "맛집 25곳", symbol: "signpost.right.and.left.fill", metric: .places, target: 25),
    .init(id: "streak3", title: "3일 연속 기록", symbol: "flame.fill", metric: .bestStreak, target: 3),
    .init(id: "streak7", title: "7일 연속 기록", symbol: "flame.circle.fill", metric: .bestStreak, target: 7),
    .init(id: "streak14", title: "14일 연속 기록", symbol: "bolt.heart.fill", metric: .bestStreak, target: 14),
    .init(id: "streak30", title: "30일 연속 기록", symbol: "medal.fill", metric: .bestStreak, target: 30),
    .init(id: "rating1", title: "첫 별점", symbol: "star.leadinghalf.filled", metric: .ratedMeals, target: 1),
    .init(id: "rating10", title: "별점 10번", symbol: "star.square.fill", metric: .ratedMeals, target: 10),
    .init(id: "five1", title: "첫 만점", symbol: "star.fill", metric: .fiveStarMeals, target: 1),
    .init(id: "five10", title: "만점 10번", symbol: "stars", metric: .fiveStarMeals, target: 10),
    .init(id: "memo1", title: "첫 메모", symbol: "text.quote", metric: .memoMeals, target: 1),
    .init(id: "memo10", title: "메모 10개", symbol: "note.text", metric: .memoMeals, target: 10),
    .init(id: "decor1", title: "첫 꾸미기", symbol: "paintbrush.pointed.fill", metric: .decoratedCutouts, target: 1),
    .init(id: "decor20", title: "꾸민 누끼 20개", symbol: "paintpalette.fill", metric: .decoratedCutouts, target: 20),
]

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
        case .memoMeals: current = stats.memoMeals
        case .decoratedCutouts: current = stats.decoratedCutouts
        }
        return Achievement(id: def.id, title: L10n.text(def.title), symbol: def.symbol,
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
                    async let loadedCutouts = persistence.allCutouts()
                    async let loadedMeals = persistence.allMeals()
                    let (cutouts, meals) = try await (loadedCutouts, loadedMeals)
                    var stats = AchievementStats()
                    stats.cutouts = cutouts.count
                    stats.meals = meals.count
                    stats.places = Set(meals.compactMap { $0.place?.id }).count
                    stats.bestStreak = MealStreak.calculate(meals: meals, now: now).best
                    stats.ratedMeals = meals.filter { $0.rating != nil }.count
                    stats.fiveStarMeals = meals.filter { $0.rating == 5 }.count
                    stats.memoMeals = meals.filter {
                        !$0.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }.count
                    stats.decoratedCutouts = cutouts.filter {
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
