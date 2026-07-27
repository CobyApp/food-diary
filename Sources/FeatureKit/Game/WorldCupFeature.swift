import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct WorldCupFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot]
        public var currentRound: [CutoutSnapshot] = []
        public var nextRound: [CutoutSnapshot] = []
        public var pairIndex = 0
        public var champion: CutoutSnapshot?
        public var championInfo: GameResultInfo?
        public var info: [UUID: GameResultInfo] = [:]
        public init(cutouts: [CutoutSnapshot]) { self.cutouts = cutouts }

        public var currentPair: (CutoutSnapshot, CutoutSnapshot)? {
            guard pairIndex + 1 < currentRound.count else { return nil }
            return (currentRound[pairIndex], currentRound[pairIndex + 1])
        }

        public var roundName: String {
            switch currentRound.count {
            case 2: return L10n.text("결승")
            default: return L10n.format("round.count", currentRound.count)
            }
        }
    }

    public enum Action: Equatable {
        case start
        case pick(CutoutSnapshot)
        case infoLoaded(GameResultInfo?)
        case infoTableLoaded([UUID: GameResultInfo])
        case playAgain
        case close
    }

    @Dependency(\.random) var random
    @Dependency(\.persistence) var persistence

    public init() {}

    // Largest power of two <= count, clamped to 2...16.
    private func bracketSize(_ count: Int) -> Int {
        guard count >= 2 else { return 0 }
        var size = 1
        while size * 2 <= min(count, 16) { size *= 2 }
        return size
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .start:
                let size = bracketSize(state.cutouts.count)
                guard size >= 2 else { return .none }
                state.currentRound = Array(random.shuffled(state.cutouts).prefix(size))
                state.nextRound = []
                state.pairIndex = 0
                state.champion = nil
                state.championInfo = nil
                return .run { send in
                    let meals = (try? await persistence.allMeals()) ?? []
                    var table: [UUID: GameResultInfo] = [:]
                    for meal in meals {
                        guard let info = GameResultInfo.from(meal) else { continue }
                        for cutout in meal.cutouts { table[cutout.id] = info }
                    }
                    await send(.infoTableLoaded(table))
                }

            case let .pick(winner):
                state.nextRound.append(winner)
                state.pairIndex += 2
                if state.pairIndex >= state.currentRound.count {
                    // Round finished: promote to the next round or crown the champion.
                    if state.nextRound.count == 1 {
                        let champ = state.nextRound[0]
                        state.champion = champ
                        return .run { send in
                            let meal = try? await persistence.mealByCutout(champ.id)
                            await send(.infoLoaded(GameResultInfo.from(meal)))
                        }
                    }
                    state.currentRound = state.nextRound
                    state.nextRound = []
                    state.pairIndex = 0
                }
                return .none

            case let .infoLoaded(info):
                state.championInfo = info
                return .none

            case let .infoTableLoaded(table):
                state.info = table
                return .none

            case .playAgain:
                state.currentRound = []
                state.nextRound = []
                state.pairIndex = 0
                state.champion = nil
                state.championInfo = nil
                return .send(.start)

            case .close:
                return .none
            }
        }
    }
}
