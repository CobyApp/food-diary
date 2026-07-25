import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct GachaFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot]
        public var result: CutoutSnapshot?
        public var resultPlace: String?
        public var isSpinning = false
        public var drawnIDs: Set<UUID> = []
        public init(cutouts: [CutoutSnapshot]) { self.cutouts = cutouts }
    }

    public enum Action: Equatable {
        case pullLever
        case revealed(CutoutSnapshot)
        case placeLoaded(String?)
        case playAgain
        case close
    }

    @Dependency(\.random) var random
    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .pullLever:
                var pool = state.cutouts.filter { !state.drawnIDs.contains($0.id) }
                if pool.isEmpty {
                    state.drawnIDs = []
                    pool = state.cutouts
                }
                guard let pick = random.pick(pool) else { return .none }
                state.isSpinning = true
                state.result = pick
                state.resultPlace = nil
                state.drawnIDs.insert(pick.id)
                return .run { send in
                    let place = try? await persistence.mealByCutout(pick.id)?.place?.name
                    await send(.placeLoaded(place ?? nil))
                }

            case let .revealed(cutout):
                state.result = cutout
                return .none

            case let .placeLoaded(place):
                state.resultPlace = place
                return .none

            case .playAgain:
                state.result = nil
                state.resultPlace = nil
                state.isSpinning = false
                return .none

            case .close:
                return .none
            }
        }
    }
}
