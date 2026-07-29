import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct FoodMapFeature {
    @ObservableState
    public struct State: Equatable {
        public var meals: [FoodEntrySnapshot] = []
        public var selectedMealID: UUID?
        public var isLoading = false
        public init() {}

        public var pins: [FoodEntrySnapshot] {
            meals.filter { $0.place?.coordinate != nil }
        }
        public var selectedMeal: FoodEntrySnapshot? {
            guard let id = selectedMealID else { return nil }
            return meals.first { $0.id == id }
        }
    }

    public enum Action: Equatable {
        case onAppear
        case mealsLoaded([FoodEntrySnapshot])
        case mealsLoadFailed
        case pinTapped(UUID)
        case dismissCard
        case cutoutsDeleted(Set<UUID>)
        case mealDeleted(UUID)
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    await send(.mealsLoaded(try await persistence.allEntries()))
                } catch: { _, send in
                    await send(.mealsLoadFailed)
                }
            case let .mealsLoaded(meals):
                state.isLoading = false
                state.meals = meals
                if let selectedMealID = state.selectedMealID,
                   !state.meals.contains(where: { $0.id == selectedMealID }) {
                    state.selectedMealID = nil
                }
                return .none
            case .mealsLoadFailed:
                state.isLoading = false
                return .none
            case let .pinTapped(id):
                state.selectedMealID = id
                return .none
            case .dismissCard:
                state.selectedMealID = nil
                return .none
            case let .cutoutsDeleted(ids):
                // A food and its record are the same row now, so this is a filter.
                state.meals.removeAll { ids.contains($0.id) }
                if let selectedMealID = state.selectedMealID,
                   !state.meals.contains(where: { $0.id == selectedMealID }) {
                    state.selectedMealID = nil
                }
                return .none
            case let .mealDeleted(id):
                state.meals.removeAll { $0.id == id }
                if state.selectedMealID == id {
                    state.selectedMealID = nil
                }
                return .none
            }
        }
    }
}
