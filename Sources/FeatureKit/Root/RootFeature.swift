import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct RootFeature {
    public enum Tab: Equatable { case collection, capture }

    @ObservableState
    public struct State: Equatable {
        public var tab: Tab = .collection
        public var collection = CollectionFeature.State()
        public var capture = CaptureFeature.State()
        public var path = StackState<MealDetailFeature.State>()
        public init() {}
    }

    public enum Action {
        case tabChanged(Tab)
        case collection(CollectionFeature.Action)
        case capture(CaptureFeature.Action)
        case pushDetail(UUID)
        case path(StackAction<MealDetailFeature.State, MealDetailFeature.Action>)
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.collection, action: \.collection) { CollectionFeature() }
        Scope(state: \.capture, action: \.capture) { CaptureFeature() }

        Reduce { state, action in
            switch action {
            case let .tabChanged(tab):
                state.tab = tab
                return .none

            case let .collection(.cutoutTapped(cutoutID)):
                return .run { send in
                    if let meal = try await persistence.mealByCutout(cutoutID) {
                        await send(.pushDetail(meal.id))
                    }
                }

            case let .pushDetail(mealID):
                state.path.append(MealDetailFeature.State(mealID: mealID))
                return .none

            // When a save finishes on the capture tab, refresh the collection and switch to it.
            case .capture(.saved):
                state.tab = .collection
                return .send(.collection(.onAppear))

            // Pop detail after a delete.
            case let .path(.element(id: id, action: .deleted)):
                state.path.pop(from: id)
                return .send(.collection(.onAppear))

            case .collection, .capture, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            MealDetailFeature()
        }
    }
}
