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
        public var firstRevealedIndex: Int?
        public var secondRevealedIndex: Int?
        public var moves = 0
        public var result: CutoutSnapshot?
        public var resultPlace: String?
        public init(cutouts: [CutoutSnapshot]) { self.cutouts = cutouts }

        public var revealedIndices: Set<Int> {
            Set([firstRevealedIndex, secondRevealedIndex].compactMap { $0 })
        }
    }

    public enum Action: Equatable {
        case start
        case flip(Int)
        case hideMismatch
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
            case .start:
                let picks = Array(random.shuffled(state.cutouts).prefix(3))
                state.cards = random.shuffled(picks + picks)
                state.firstRevealedIndex = nil
                state.secondRevealedIndex = nil
                state.moves = 0
                state.result = nil
                state.resultPlace = nil
                return .none

            case let .flip(index):
                guard
                    state.cards.indices.contains(index),
                    !state.revealedIndices.contains(index),
                    state.secondRevealedIndex == nil,
                    state.result == nil
                else { return .none }

                if state.firstRevealedIndex == nil {
                    state.firstRevealedIndex = index
                    return .none
                }

                state.secondRevealedIndex = index
                state.moves += 1
                let first = state.cards[state.firstRevealedIndex!]
                let second = state.cards[index]
                guard first.id == second.id else { return .none }
                state.result = second
                return .run { send in
                    let place = try? await persistence.mealByCutout(second.id)?.place?.name
                    await send(.placeLoaded(place ?? nil))
                }

            case .hideMismatch:
                guard state.result == nil else { return .none }
                state.firstRevealedIndex = nil
                state.secondRevealedIndex = nil
                return .none

            case let .placeLoaded(place):
                state.resultPlace = place
                return .none

            case .playAgain:
                return .send(.start)

            case .close:
                return .none
            }
        }
    }
}
