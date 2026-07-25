import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct FoodMapFeature {
    @ObservableState
    public struct State: Equatable {
        public var meals: [MealSnapshot] = []
        public var selectedMealID: UUID?
        public init() {}

        public var pins: [MealSnapshot] {
            meals.filter { $0.place?.coordinate != nil }
        }
        public var selectedMeal: MealSnapshot? {
            guard let id = selectedMealID else { return nil }
            return meals.first { $0.id == id }
        }
    }

    public enum Action: Equatable {
        case onAppear
        case mealsLoaded([MealSnapshot])
        case pinTapped(UUID)
        case dismissCard
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in await send(.mealsLoaded(try await persistence.allMeals())) }
            case let .mealsLoaded(meals):
                state.meals = meals
                return .none
            case let .pinTapped(id):
                state.selectedMealID = id
                return .none
            case .dismissCard:
                state.selectedMealID = nil
                return .none
            }
        }
    }
}
