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
        public var resultPlace: String?
        public init(cutouts: [CutoutSnapshot]) { self.cutouts = cutouts }

        public var result: CutoutSnapshot? {
            guard let i = revealedIndex, cards.indices.contains(i) else { return nil }
            return cards[i]
        }
    }

    public enum Action: Equatable {
        case start
        case flip(Int)
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
                state.cards = Array(random.shuffled(state.cutouts).prefix(6))
                state.revealedIndex = nil
                state.resultPlace = nil
                return .none

            case let .flip(index):
                guard state.revealedIndex == nil, state.cards.indices.contains(index) else { return .none }
                state.revealedIndex = index
                let picked = state.cards[index]
                return .run { send in
                    let place = try? await persistence.mealByCutout(picked.id)?.place?.name
                    await send(.placeLoaded(place ?? nil))
                }

            case let .placeLoaded(place):
                state.resultPlace = place
                return .none

            case .playAgain:
                state.revealedIndex = nil
                state.resultPlace = nil
                return .send(.start)

            case .close:
                return .none
            }
        }
    }
}
