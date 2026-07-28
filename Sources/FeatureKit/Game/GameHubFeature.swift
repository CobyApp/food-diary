import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public enum GameDestination {
    case worldCup(WorldCupFeature)
}

extension GameDestination.State: Equatable {}

public enum GameKind: Equatable, CaseIterable {
    case worldCup
    public var title: String {
        switch self {
        case .worldCup: return L10n.text("음식 월드컵")
        }
    }
    public var symbol: String {
        switch self {
        case .worldCup: return "crown.fill"
        }
    }
    public var subtitle: String {
        switch self {
        case .worldCup: return L10n.text("끝까지 고르는 취향전")
        }
    }
    public var minimum: Int {
        switch self {
        case .worldCup: return 2
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
                case .worldCup: state.game = .worldCup(.init(cutouts: pool))
                }
                return .none

            case .game(.presented(.worldCup(.close))):
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
