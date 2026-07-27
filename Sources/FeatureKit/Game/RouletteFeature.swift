import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct RouletteFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot]
        public var reel: [CutoutSnapshot] = []
        public var result: CutoutSnapshot?
        public var resultInfo: GameResultInfo?
        public var isSpinning = false
        public var lastResultID: UUID?
        public init(cutouts: [CutoutSnapshot]) { self.cutouts = cutouts }
    }

    public enum Action: Equatable {
        case appear
        case spin
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
            case .appear:
                if state.reel.isEmpty {
                    // A longer reel for the scrolling visual.
                    state.reel = (0..<3).flatMap { _ in random.shuffled(state.cutouts) }
                }
                return .none

            case .spin:
                let fresh = state.cutouts.filter { $0.id != state.lastResultID }
                guard let pick = random.pick(fresh.isEmpty ? state.cutouts : fresh) else { return .none }
                state.isSpinning = true
                state.result = pick
                state.resultInfo = nil
                state.lastResultID = pick.id
                return .run { send in
                    let meal = try? await persistence.mealByCutout(pick.id)
                    await send(.infoLoaded(GameResultInfo.from(meal)))
                }

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
