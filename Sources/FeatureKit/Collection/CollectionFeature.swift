import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct CollectionFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot] = []
        public var isLoading = false
        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
        case cutoutsLoaded([CutoutSnapshot])
        case cutoutTapped(UUID)
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let cutouts = try await persistence.allCutouts()
                    await send(.cutoutsLoaded(cutouts))
                } catch: { _, send in
                    await send(.cutoutsLoaded([]))
                }
            case let .cutoutsLoaded(cutouts):
                state.isLoading = false
                state.cutouts = cutouts
                return .none
            case .cutoutTapped:
                // Navigation handled by the parent (RootFeature).
                return .none
            }
        }
    }
}
