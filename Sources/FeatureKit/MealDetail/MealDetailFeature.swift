import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct MealDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public let mealID: UUID
        public var meal: MealSnapshot?
        public init(mealID: UUID) { self.mealID = mealID }
    }

    public enum Action: Equatable {
        case task
        case mealLoaded(MealSnapshot?)
        case deleteTapped
        case deleted
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let id = state.mealID
                return .run { send in await send(.mealLoaded(try await persistence.meal(id))) }
            case let .mealLoaded(meal):
                state.meal = meal
                return .none
            case .deleteTapped:
                let id = state.mealID
                return .run { send in
                    try await persistence.deleteMeal(id)
                    await send(.deleted)
                }
            case .deleted:
                return .none
            }
        }
    }
}
