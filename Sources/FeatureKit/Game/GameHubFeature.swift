import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public enum GameDestination {
    case gacha(GachaFeature)
    case worldCup(WorldCupFeature)
    case cardFlip(CardFlipFeature)
    case roulette(RouletteFeature)
}

extension GameDestination.State: Equatable {}

public enum GameKind: Equatable, CaseIterable {
    case gacha, worldCup, cardFlip, roulette
    public var title: String {
        switch self {
        case .gacha: return "가챠 뽑기"
        case .worldCup: return "음식 월드컵"
        case .cardFlip: return "카드 뒤집기"
        case .roulette: return "룰렛 슬롯"
        }
    }
    public var emoji: String {
        switch self {
        case .gacha: return "🎰"
        case .worldCup: return "🏆"
        case .cardFlip: return "🃏"
        case .roulette: return "🎡"
        }
    }
    public var minimum: Int { self == .worldCup ? 2 : 1 }
}

@Reducer
public struct GameHubFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot]
        @Presents public var game: GameDestination.State?
        public init(cutouts: [CutoutSnapshot] = [], game: GameDestination.State? = nil) {
            self.cutouts = cutouts
            self.game = game
        }
    }

    public enum Action {
        case onAppear
        case cutoutsLoaded([CutoutSnapshot])
        case gameTapped(GameKind)
        case game(PresentationAction<GameDestination.Action>)
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    await send(.cutoutsLoaded(try await persistence.allCutouts()))
                }

            case let .cutoutsLoaded(cutouts):
                state.cutouts = cutouts
                return .none

            case let .gameTapped(kind):
                guard state.cutouts.count >= kind.minimum else { return .none }
                let pool = state.cutouts
                switch kind {
                case .gacha: state.game = .gacha(.init(cutouts: pool))
                case .worldCup: state.game = .worldCup(.init(cutouts: pool))
                case .cardFlip: state.game = .cardFlip(.init(cutouts: pool))
                case .roulette: state.game = .roulette(.init(cutouts: pool))
                }
                return .none

            case .game(.presented(.gacha(.close))),
                 .game(.presented(.worldCup(.close))),
                 .game(.presented(.cardFlip(.close))),
                 .game(.presented(.roulette(.close))):
                state.game = nil
                return .none

            case .game:
                return .none
            }
        }
        .ifLet(\.$game, action: \.game)
    }
}
