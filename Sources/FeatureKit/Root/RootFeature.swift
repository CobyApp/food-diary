import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct RootFeature {
    public enum Tab: Equatable, Hashable { case collection, capture, game, map }

    @ObservableState
    public struct State: Equatable {
        public var tab: Tab = .collection
        public var collection = CollectionFeature.State()
        public var capture = CaptureFeature.State()
        public var gameHub = GameHubFeature.State()
        public var foodMap = FoodMapFeature.State()
        public var path = StackState<MealDetailFeature.State>()
        public init() {}
    }

    public enum Action {
        case tabChanged(Tab)
        case collection(CollectionFeature.Action)
        case capture(CaptureFeature.Action)
        case gameHub(GameHubFeature.Action)
        case foodMap(FoodMapFeature.Action)
        case pushDetail(UUID)
        case path(StackAction<MealDetailFeature.State, MealDetailFeature.Action>)
    }

    @Dependency(\.persistence) var persistence
    @Dependency(\.widgetData) var widgetData

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.collection, action: \.collection) { CollectionFeature() }
        Scope(state: \.capture, action: \.capture) { CaptureFeature() }
        Scope(state: \.gameHub, action: \.gameHub) { GameHubFeature() }
        Scope(state: \.foodMap, action: \.foodMap) { FoodMapFeature() }

        Reduce { state, action in
            switch action {
            case let .tabChanged(tab):
                state.tab = tab
                return .none

            case let .collection(.cutoutsDeleted(ids)):
                return .merge(
                    .send(.foodMap(.cutoutsDeleted(ids))),
                    .run { _ in
                        let meals = (try? await persistence.allMeals()) ?? []
                        guard let latest = meals.first else {
                            await widgetData.clear()
                            return
                        }
                        let streak = MealStreak.calculate(meals: meals, now: Date()).current
                        await widgetData.update(latest, streak)
                    }
                )

            case let .pushDetail(mealID):
                state.path.append(MealDetailFeature.State(mealID: mealID))
                return .none

            // When a save finishes on the capture tab, refresh the collection and switch to it.
            case let .capture(.saved(meal)):
                state.tab = .collection
                return .merge(
                    .send(.collection(.onAppear)),
                    .send(.collection(.streakOnAppear)),
                    .run { send in
                        let meals = (try? await persistence.allMeals()) ?? [meal]
                        let streak = MealStreak.calculate(meals: meals, now: Date()).current
                        await widgetData.update(meal, streak)
                    }
                )

            // Pop detail after a delete.
            case let .path(.element(id: id, action: .deleted)):
                state.path.pop(from: id)
                return .merge(
                    .send(.collection(.onAppear)),
                    .send(.collection(.streakOnAppear)),
                    .send(.foodMap(.onAppear)),
                    .run { _ in
                        let meals = (try? await persistence.allMeals()) ?? []
                        guard let latest = meals.first else {
                            await widgetData.clear()
                            return
                        }
                        let streak = MealStreak.calculate(meals: meals, now: Date()).current
                        await widgetData.update(latest, streak)
                    }
                )

            case .collection, .capture, .gameHub, .foodMap, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            MealDetailFeature()
        }
    }
}
