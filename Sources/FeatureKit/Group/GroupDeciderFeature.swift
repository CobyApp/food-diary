import ComposableArchitecture
import Foundation
import Models
import ClientKit
import UIKit

/// Game Center group decider: the mock-tested multiplayer state machine.
///
/// Phases flow idle → authenticating → matchmaking → lobby → voting → reveal →
/// champion. This reducer consumes `MultiplayerClient` events, builds a
/// `MenuPick` from a chosen cutout (thumbnail + memo + place via
/// `persistence.mealByCutout`), and — once every known player has submitted
/// and this device is host (lexicographically-smallest player id) — broadcasts
/// a bracket (`order = menus.keys.sorted()`) and runs it as a timed voting
/// World Cup: one match at a time, 5 s to vote, majority advances (ties go to
/// whichever candidate is earlier in the bracket order), until a champion
/// remains. Only the host tallies votes and advances the bracket; every other
/// player renders whatever the host broadcasts. The countdown is driven by
/// `@Dependency(\.continuousClock)` (never wall-clock `Task.sleep`), so it is
/// fully deterministic and `TestClock`-drivable. It only touches
/// MultiplayerClient / PersistenceClient (never GameKit), so it stays fully
/// mockable in tests.
@Reducer
public struct GroupDeciderFeature {
    public enum Phase: Equatable {
        case idle, authenticating, matchmaking, lobby, voting, reveal, champion
    }

    /// The outcome of the most recently tallied match.
    public struct Tally: Equatable, Sendable {
        public var winner: String
        public var left: Int
        public var right: Int
        public init(winner: String, left: Int, right: Int) {
            self.winner = winner; self.left = left; self.right = right
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var phase: Phase = .idle
        public var localPlayer: LocalPlayer?
        public var players: [RemotePlayer] = []
        public var menus: [String: MenuPick] = [:]
        public var myCutouts: [CutoutSnapshot] = []

        // Bracket bookkeeping.
        public var order: [String] = []           // full candidate order (from the host), fixed for the tournament
        public var round: [String] = []            // current round's candidate ids, in bracket order
        public var pairIndex: Int = 0               // index of the live match within `round`
        public var nextRound: [String] = []         // winners accumulated so far for the round after this one
        public var votes: [String: String] = [:]    // voterID -> candidateID, current match only
        public var myVote: String?
        public var secondsLeft: Int = 0
        public var lastTally: Tally?

        public var championPick: MenuPick?
        public var errorText: String?

        public init(
            phase: Phase = .idle,
            localPlayer: LocalPlayer? = nil,
            players: [RemotePlayer] = [],
            menus: [String: MenuPick] = [:],
            myCutouts: [CutoutSnapshot] = []
        ) {
            self.phase = phase
            self.localPlayer = localPlayer
            self.players = players
            self.menus = menus
            self.myCutouts = myCutouts
        }

        // All known participant ids = local + remotes.
        public var allPlayerIDs: [String] {
            (players.map(\.id) + (localPlayer.map { [$0.id] } ?? [])).sorted()
        }

        public var isHost: Bool {
            guard let me = localPlayer?.id, let host = allPlayerIDs.min() else { return false }
            return me == host
        }

        public var mySubmitted: Bool { localPlayer.map { menus[$0.id] != nil } ?? false }

        public var allSubmitted: Bool {
            !allPlayerIDs.isEmpty && allPlayerIDs.allSatisfy { menus[$0] != nil }
        }

        /// The two `MenuPick`s of the currently-live match, if one exists.
        public var currentPair: (MenuPick, MenuPick)? {
            guard pairIndex + 1 < round.count,
                  let left = menus[round[pairIndex]],
                  let right = menus[round[pairIndex + 1]]
            else { return nil }
            return (left, right)
        }

        /// Winners accumulated so far toward the round after this one.
        public var nextRoundSeeds: [String] { nextRound }
    }

    public enum Action: Equatable {
        case onAppear
        case cutoutsLoaded([CutoutSnapshot])
        case startTapped
        case authenticated(LocalPlayer)
        case matchStarted
        case eventReceived(MultiplayerEvent)
        case cutoutPicked(CutoutSnapshot)
        case menuBuilt(MenuPick)
        case voteTapped(String)
        case tick
        case hostTally
        case advance
        case failed(String)
        case leave
    }

    private enum CancelID { case countdown, reveal }

    @Dependency(\.multiplayer) var multiplayer
    @Dependency(\.persistence) var persistence
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    await send(.cutoutsLoaded((try? await persistence.allCutouts()) ?? []))
                }

            case let .cutoutsLoaded(cutouts):
                state.myCutouts = cutouts
                return .none

            case .startTapped:
                state.phase = .authenticating
                return .run { send in
                    do {
                        let me = try await multiplayer.authenticate()
                        await send(.authenticated(me))
                    } catch {
                        await send(.failed("게임센터 로그인이 필요해요"))
                    }
                }

            case let .authenticated(me):
                state.localPlayer = me
                state.phase = .matchmaking
                return .run { send in
                    do {
                        try await multiplayer.startMatch()
                        await send(.matchStarted)
                    } catch {
                        await send(.failed("매칭이 취소됐어요"))
                    }
                }

            case .matchStarted:
                state.phase = .lobby
                return .run { send in
                    for await event in multiplayer.events() {
                        await send(.eventReceived(event))
                    }
                }

            case let .eventReceived(event):
                switch event {
                case let .playersChanged(list):
                    state.players = list
                    return maybeStartBracket(into: &state)

                case let .received(.menu(pick), _):
                    state.menus[pick.playerID] = pick
                    return maybeStartBracket(into: &state)

                case let .received(.bracket(order), _):
                    state.order = order
                    return .none

                case let .received(.pair(index), _):
                    return applyPair(index, into: &state)

                case let .received(.vote(candidateID), from: voter):
                    state.votes[voter] = candidateID
                    return .none

                case let .received(.roundResult(winner, left, right), _):
                    // The host already knows this result from its own tally.
                    guard !state.isHost else { return .none }
                    state.lastTally = Tally(winner: winner, left: left, right: right)
                    state.nextRound.append(winner)
                    state.phase = .reveal
                    return .none

                case let .received(.champion(id), _):
                    state.championPick = state.menus[id]
                    state.phase = .champion
                    return .merge(.cancel(id: CancelID.countdown), .cancel(id: CancelID.reveal))

                case .matchEnded:
                    state.phase = .idle
                    return .none
                }

            case let .cutoutPicked(cutout):
                guard let me = state.localPlayer else { return .none }
                return .run { send in
                    let meal = try? await persistence.mealByCutout(cutout.id)
                    let data = ImageStore.disk(directory: ImageStore.cutoutsDirectory)
                        .load(cutout.fileName) ?? Data()
                    let thumb = await GroupDeciderFeature.thumbnail(from: data)
                    let pick = MenuPick(
                        playerID: me.id, playerName: me.displayName, thumbnail: thumb,
                        memo: meal?.memo ?? "", placeName: meal?.place?.name ?? "",
                        address: meal?.place?.address ?? ""
                    )
                    await send(.menuBuilt(pick))
                }

            case let .menuBuilt(pick):
                state.menus[pick.playerID] = pick
                let broadcast: Effect<Action> = .run { _ in
                    try? await multiplayer.send(.menu(pick))
                }
                return .merge(broadcast, maybeStartBracket(into: &state))

            case let .voteTapped(candidateID):
                guard state.myVote == nil,
                      let pair = pairIDs(state), pair.contains(candidateID),
                      let me = state.localPlayer?.id
                else { return .none }
                state.myVote = candidateID
                state.votes[me] = candidateID
                return .run { _ in try? await multiplayer.send(.vote(candidateID: candidateID)) }

            case .tick:
                guard state.secondsLeft > 0 else { return .none }
                state.secondsLeft -= 1
                if state.secondsLeft == 0, state.isHost {
                    return .send(.hostTally)
                }
                return .none

            case .hostTally:
                guard state.isHost, let pair = pairIDs(state) else { return .none }
                let left = pair[0], right = pair[1]
                let leftVotes = state.votes.values.filter { $0 == left }.count
                let rightVotes = state.votes.values.filter { $0 == right }.count
                // Majority wins; a tie (including no votes at all) goes to `left`,
                // which is always the earlier candidate in the bracket order.
                let winner = leftVotes >= rightVotes ? left : right
                return resolveMatch(winner: winner, left: leftVotes, right: rightVotes, into: &state)

            case .advance:
                guard state.isHost else { return .none }
                return hostAdvance(into: &state)

            case let .failed(text):
                state.errorText = text
                state.phase = .idle
                return .none

            case .leave:
                multiplayer.disconnect()
                state = State(myCutouts: state.myCutouts)
                return .merge(.cancel(id: CancelID.countdown), .cancel(id: CancelID.reveal))
            }
        }
    }

    // MARK: - Bracket / voting helpers

    /// Host authority: when everyone has submitted and no bracket has been
    /// built yet, sort the candidate ids for a deterministic order, broadcast
    /// `.bracket` + the first `.pair`, and start the first countdown.
    private func maybeStartBracket(into state: inout State) -> Effect<Action> {
        guard state.isHost, state.allSubmitted, state.order.isEmpty else { return .none }
        let order = state.menus.keys.sorted()
        state.order = order
        state.round = order
        let countdown = beginMatch(0, into: &state)
        return .merge(
            countdown,
            .run { _ in try? await multiplayer.send(.bracket(order)) },
            .run { _ in try? await multiplayer.send(.pair(index: 0)) }
        )
    }

    /// Applies a `.pair(index:)` message from the host: promotes `nextRound`
    /// into `round` if this pair starts a fresh round, then begins the match.
    private func applyPair(_ index: Int, into state: inout State) -> Effect<Action> {
        if state.round.isEmpty {
            state.round = state.order
        } else if index == 0, state.pairIndex + 1 >= state.round.count, !state.nextRound.isEmpty {
            state.round = state.nextRound
            state.nextRound = []
        }
        return beginMatch(index, into: &state)
    }

    /// Sets the live match index, resets votes only if the live pair actually
    /// changed, and (re)starts the 5 s countdown effect.
    private func beginMatch(_ index: Int, into state: inout State) -> Effect<Action> {
        let previousPair = pairIDs(state)
        state.pairIndex = index
        if pairIDs(state) != previousPair {
            state.votes = [:]
            state.myVote = nil
        }
        state.phase = .voting
        state.secondsLeft = 5
        return .run { send in
            for await _ in clock.timer(interval: .seconds(1)) {
                await send(.tick)
            }
        }
        .cancellable(id: CancelID.countdown, cancelInFlight: true)
    }

    /// Records a match result (real vote tally or an automatic bye), holds on
    /// `.reveal` briefly, then triggers `.advance` to move the bracket forward.
    private func resolveMatch(winner: String, left: Int, right: Int, into state: inout State) -> Effect<Action> {
        state.lastTally = Tally(winner: winner, left: left, right: right)
        state.nextRound.append(winner)
        state.phase = .reveal
        return .merge(
            .run { _ in try? await multiplayer.send(.roundResult(winnerID: winner, leftVotes: left, rightVotes: right)) },
            .run { send in
                try? await clock.sleep(for: .milliseconds(1500))
                await send(.advance)
            }
            .cancellable(id: CancelID.reveal, cancelInFlight: true)
        )
    }

    /// Host-only: moves the bracket past the just-resolved match — folding in
    /// a bye for a trailing unpaired candidate, starting the next match, or
    /// crowning a champion once the bracket is exhausted.
    private func hostAdvance(into state: inout State) -> Effect<Action> {
        let next = state.pairIndex + 2

        // Odd round size: the trailing unpaired candidate advances automatically.
        if next == state.round.count - 1 {
            let bye = state.round[next]
            state.pairIndex = next
            return resolveMatch(winner: bye, left: 0, right: 0, into: &state)
        }

        guard next < state.round.count else {
            // The round is exhausted.
            if state.nextRound.count <= 1 {
                guard let championID = state.nextRound.first ?? state.round.first else { return .none }
                state.championPick = state.menus[championID]
                state.phase = .champion
                state.nextRound = []
                return .merge(
                    .cancel(id: CancelID.countdown),
                    .cancel(id: CancelID.reveal),
                    .run { _ in try? await multiplayer.send(.champion(championID)) }
                )
            }
            state.round = state.nextRound
            state.nextRound = []
            let countdown = beginMatch(0, into: &state)
            return .merge(countdown, .run { _ in try? await multiplayer.send(.pair(index: 0)) })
        }

        let countdown = beginMatch(next, into: &state)
        return .merge(countdown, .run { _ in try? await multiplayer.send(.pair(index: next)) })
    }

    private func pairIDs(_ state: State) -> [String]? {
        guard state.pairIndex + 1 < state.round.count else { return nil }
        return [state.round[state.pairIndex], state.round[state.pairIndex + 1]]
    }

    @MainActor
    static func thumbnail(from data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let side: CGFloat = 150
        let scale = min(side / max(image.size.width, 1), side / max(image.size.height, 1), 1)
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let scaled = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return scaled.jpegData(compressionQuality: 0.6) ?? data
    }
}
