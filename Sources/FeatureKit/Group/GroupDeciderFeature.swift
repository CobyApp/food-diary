import ComposableArchitecture
import Foundation
import Models
import ClientKit
import UIKit

/// Game Center group decider: the mock-tested multiplayer state machine.
///
/// Phases flow idle → authenticating → matchmaking → lobby → result. This
/// reducer consumes `MultiplayerClient` events, builds a `MenuPick` from a
/// chosen cutout (thumbnail + memo + place via `persistence.mealByCutout`),
/// and — once every known player has submitted and this device is host
/// (lexicographically-smallest player id) — picks a winner via `RandomClient`
/// and broadcasts `.result`. It only touches MultiplayerClient / RandomClient /
/// PersistenceClient (never GameKit), so it stays fully mockable in tests.
@Reducer
public struct GroupDeciderFeature {
    public enum Phase: Equatable { case idle, authenticating, matchmaking, lobby, result }

    @ObservableState
    public struct State: Equatable {
        public var phase: Phase = .idle
        public var localPlayer: LocalPlayer?
        public var players: [RemotePlayer] = []
        public var menus: [String: MenuPick] = [:]
        public var myCutouts: [CutoutSnapshot] = []
        public var winner: MenuPick?
        public var errorText: String?

        public init(
            phase: Phase = .idle,
            localPlayer: LocalPlayer? = nil,
            players: [RemotePlayer] = [],
            menus: [String: MenuPick] = [:],
            myCutouts: [CutoutSnapshot] = [],
            winner: MenuPick? = nil
        ) {
            self.phase = phase
            self.localPlayer = localPlayer
            self.players = players
            self.menus = menus
            self.myCutouts = myCutouts
            self.winner = winner
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
        case resultResolved(MenuPick?)
        case failed(String)
        case leave
    }

    @Dependency(\.multiplayer) var multiplayer
    @Dependency(\.random) var random
    @Dependency(\.persistence) var persistence

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
                    return maybeRunHost(state)

                case let .received(.menu(pick), _):
                    state.menus[pick.playerID] = pick
                    return maybeRunHost(state)

                case let .received(.result(winnerID), _):
                    return .send(.resultResolved(state.menus[winnerID]))

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
                return .merge(broadcast, maybeRunHost(state))

            case let .resultResolved(pick):
                state.winner = pick
                state.phase = .result
                return .none

            case let .failed(text):
                state.errorText = text
                state.phase = .idle
                return .none

            case .leave:
                multiplayer.disconnect()
                state = State(myCutouts: state.myCutouts)
                return .none
            }
        }
    }

    // Host authority: when everyone has submitted and we are host, pick a winner
    // (via RandomClient over the submitted player IDs) and broadcast it, then
    // resolve locally through the same `.resultResolved` action the non-host
    // path uses — keeping a single place where `winner`/`phase` are mutated.
    private func maybeRunHost(_ state: State) -> Effect<Action> {
        guard state.isHost, state.allSubmitted, state.winner == nil else { return .none }
        // Reuse RandomClient.pick over placeholder snapshots whose fileName
        // carries the playerID, so selection is injectable/deterministic in
        // tests without adding a new RandomClient API.
        let ids = state.menus.keys.sorted().map {
            CutoutSnapshot(id: UUID(), fileName: $0, createdAt: Date(), label: $0)
        }
        guard
            let winnerID = random.pick(ids)?.fileName ?? state.menus.keys.sorted().first,
            let winner = state.menus[winnerID]
        else { return .none }

        return .run { send in
            try? await multiplayer.send(.result(winnerPlayerID: winnerID))
            await send(.resultResolved(winner))
        }
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
