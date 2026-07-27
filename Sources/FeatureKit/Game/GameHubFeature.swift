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
        case .gacha: return L10n.text("가챠 뽑기")
        case .worldCup: return L10n.text("음식 월드컵")
        case .cardFlip: return L10n.text("카드 뒤집기")
        case .roulette: return L10n.text("룰렛 슬롯")
        }
    }
    public var symbol: String {
        switch self {
        case .gacha: return "capsule.portrait.fill"
        case .worldCup: return "crown.fill"
        case .cardFlip: return "rectangle.on.rectangle.angled"
        case .roulette: return "dial.high.fill"
        }
    }
    public var subtitle: String {
        switch self {
        case .gacha: return L10n.text("캡슐 속 랜덤 한 끼")
        case .worldCup: return L10n.text("끝까지 고르는 취향전")
        case .cardFlip: return L10n.text("운명처럼 한 장 픽")
        case .roulette: return L10n.text("빠르게 돌려 즉석 결정")
        }
    }
    public var minimum: Int {
        switch self {
        case .gacha: return 3
        case .worldCup: return 2
        case .cardFlip: return 3
        case .roulette: return 2
        }
    }
}

@Reducer
public struct GameHubFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot]
        @Presents public var game: GameDestination.State?
        @Presents public var groupDecider: GroupDeciderFeature.State?
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
        case groupTapped
        case groupDecider(PresentationAction<GroupDeciderFeature.Action>)
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

            case .groupTapped:
                state.groupDecider = GroupDeciderFeature.State()
                return .none

            case .groupDecider(.presented(.leave)):
                state.groupDecider = nil
                return .none

            case .groupDecider:
                return .none
            }
        }
        .ifLet(\.$game, action: \.game)
        .ifLet(\.$groupDecider, action: \.groupDecider) {
            GroupDeciderFeature()
        }
    }
}
