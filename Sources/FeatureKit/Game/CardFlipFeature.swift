import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct CardFlipFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot]
        public var cards: [CutoutSnapshot] = []
        public var revealedIndex: Int?
        public var resultInfo: GameResultInfo?
        public init(cutouts: [CutoutSnapshot]) { self.cutouts = cutouts }

        /// The flipped card IS the pick — one flip ends the game.
        public var result: CutoutSnapshot? {
            guard let i = revealedIndex, cards.indices.contains(i) else { return nil }
            return cards[i]
        }
    }

    public enum Action: Equatable {
        case start
        case flip(Int)
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
            case .start:
                state.cards = Array(random.shuffled(state.cutouts).prefix(6))
                state.revealedIndex = nil
                state.resultInfo = nil
                return .none

            case let .flip(index):
                guard
                    state.revealedIndex == nil,
                    state.cards.indices.contains(index)
                else { return .none }
                state.revealedIndex = index
                let picked = state.cards[index]
                return .run { send in
                    let meal = try? await persistence.mealByCutout(picked.id)
                    await send(.infoLoaded(GameResultInfo.from(meal)))
                }

            case let .infoLoaded(info):
                state.resultInfo = info
                return .none

            case .playAgain:
                return .send(.start)

            case .close:
                return .none
            }
        }
    }
}
