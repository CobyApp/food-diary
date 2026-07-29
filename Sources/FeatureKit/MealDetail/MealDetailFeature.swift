import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct MealDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public let entryID: UUID
        public var entry: FoodEntrySnapshot?
        public init(entryID: UUID) { self.entryID = entryID }
    }

    public enum Action: Equatable {
        case task
        case entryLoaded(FoodEntrySnapshot?)
        case deleteTapped
        case deleted
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let id = state.entryID
                return .run { send in await send(.entryLoaded(try await persistence.entry(id))) }
            case let .entryLoaded(entry):
                state.entry = entry
                return .none
            case .deleteTapped:
                let id = state.entryID
                return .run { send in
                    try await persistence.deleteEntries([id])
                    await send(.deleted)
                }
            case .deleted:
                return .none
            }
        }
    }
}
