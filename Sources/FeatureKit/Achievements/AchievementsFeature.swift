import ComposableArchitecture
import Foundation
import Models
import ClientKit

public struct Achievement: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let emoji: String
    public let target: Int
    public let current: Int
    public var unlocked: Bool { current >= target }
    public var progress: Double { target == 0 ? 1 : min(1, Double(current) / Double(target)) }
}

enum AchievementMetric { case cutouts, places, meals }

private struct AchievementDef {
    let id: String
    let title: String
    let emoji: String
    let metric: AchievementMetric
    let target: Int
}

private let achievementCatalog: [AchievementDef] = [
    .init(id: "cut1", title: "첫 누끼", emoji: "🍽", metric: .cutouts, target: 1),
    .init(id: "cut10", title: "누끼 10개", emoji: "🥉", metric: .cutouts, target: 10),
    .init(id: "cut50", title: "누끼 50개", emoji: "🥈", metric: .cutouts, target: 50),
    .init(id: "cut100", title: "누끼 100개", emoji: "🥇", metric: .cutouts, target: 100),
    .init(id: "plc1", title: "첫 맛집", emoji: "📍", metric: .places, target: 1),
    .init(id: "plc5", title: "맛집 5곳", emoji: "🗺️", metric: .places, target: 5),
    .init(id: "plc10", title: "맛집 10곳", emoji: "🌏", metric: .places, target: 10),
    .init(id: "meal30", title: "기록 30개", emoji: "📔", metric: .meals, target: 30),
]

func makeAchievements(cutouts: Int, places: Int, meals: Int) -> [Achievement] {
    achievementCatalog.map { def in
        let current: Int
        switch def.metric {
        case .cutouts: current = cutouts
        case .places: current = places
        case .meals: current = meals
        }
        return Achievement(id: def.id, title: def.title, emoji: def.emoji,
                           target: def.target, current: current)
    }
}

@Reducer
public struct AchievementsFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutoutCount = 0
        public var mealCount = 0
        public var placeCount = 0
        public init() {}

        public var achievements: [Achievement] {
            makeAchievements(cutouts: cutoutCount, places: placeCount, meals: mealCount)
        }
        public var unlockedCount: Int { achievements.filter(\.unlocked).count }
    }

    public enum Action: Equatable {
        case onAppear
        case statsLoaded(cutouts: Int, meals: Int, places: Int)
        case close
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let cutouts = try await persistence.allCutouts().count
                    let meals = try await persistence.allMeals()
                    let places = Set(meals.compactMap { $0.place?.id }).count
                    await send(.statsLoaded(cutouts: cutouts, meals: meals.count, places: places))
                }
            case let .statsLoaded(cutouts, meals, places):
                state.cutoutCount = cutouts
                state.mealCount = meals
                state.placeCount = places
                return .none
            case .close:
                return .none
            }
        }
    }
}
