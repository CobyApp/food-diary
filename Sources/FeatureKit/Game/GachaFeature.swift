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
        public var resultInfo: GameResultInfo?
        public var isSpinning = false
        public var drawnIDs: Set<UUID> = []
        public init(cutouts: [CutoutSnapshot]) { self.cutouts = cutouts }
    }

    public enum Action: Equatable {
        case pullLever
        case revealed(CutoutSnapshot)
        case infoLoaded(GameResultInfo?)
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
                state.resultInfo = nil
                state.drawnIDs.insert(pick.id)
                return .run { send in
                    let meal = try? await persistence.mealByCutout(pick.id)
                    await send(.infoLoaded(GameResultInfo.from(meal)))
                }

            case let .revealed(cutout):
                state.result = cutout
                return .none

            case let .infoLoaded(info):
                state.resultInfo = info
                return .none

            case .playAgain:
                state.result = nil
                state.resultInfo = nil
                state.isSpinning = false
                return .none

            case .close:
                return .none
            }
        }
    }
}
