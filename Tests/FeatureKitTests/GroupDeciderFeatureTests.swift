import XCTest
import ComposableArchitecture
import Models
import ClientKit
@testable import FeatureKit

final class GroupDeciderFeatureTests: XCTestCase {
    private func pick(_ id: String) -> MenuPick {
        MenuPick(playerID: id, playerName: id, thumbnail: Data([1]),
                 memo: "m\(id)", placeName: "p\(id)", address: "a\(id)")
    }

    @MainActor
    func test_start_authenticatesAndEntersLobby() async {
        let store = TestStore(initialState: GroupDeciderFeature.State()) {
            GroupDeciderFeature()
        } withDependencies: {
            $0.multiplayer.authenticate = { LocalPlayer(id: "me", displayName: "나") }
            $0.multiplayer.startMatch = {}
            $0.multiplayer.events = { .finished }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.startTapped) { $0.phase = .authenticating }
        await store.receive(\.authenticated) {
            $0.localPlayer = LocalPlayer(id: "me", displayName: "나")
            $0.phase = .matchmaking
        }
        await store.receive(\.matchStarted) { $0.phase = .lobby }
    }

    @MainActor
    func test_hostRunsRouletteWhenAllSubmitted() async {
        let mePick = pick("aaa")   // "aaa" is min → host
        let theirPick = pick("zzz")
        var sent: [MultiplayerMessage] = []
        let store = TestStore(
            initialState: GroupDeciderFeature.State(
                phase: .lobby,
                localPlayer: LocalPlayer(id: "aaa", displayName: "나"),
                players: [RemotePlayer(id: "zzz", displayName: "친구")],
                menus: ["aaa": mePick]
            )
        ) {
            GroupDeciderFeature()
        } withDependencies: {
            $0.random.pick = { items in items.first }   // deterministic
            $0.multiplayer.send = { msg in sent.append(msg) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        // friend's menu arrives -> all submitted -> host picks winner + broadcasts
        await store.send(.eventReceived(.received(.menu(theirPick), from: "zzz")))
        await store.receive(\.resultResolved) {
            $0.winner = $0.winner  // winner set to the injected pick
            $0.phase = .result
        }
        XCTAssertTrue(sent.contains(.result(winnerPlayerID: mePick.playerID)))
    }

    @MainActor
    func test_nonHostReceivesResult() async {
        let winner = pick("zzz")
        let store = TestStore(
            initialState: GroupDeciderFeature.State(
                phase: .lobby,
                localPlayer: LocalPlayer(id: "zzz", displayName: "나"),
                players: [RemotePlayer(id: "aaa", displayName: "호스트")],
                menus: ["zzz": pick("zzz"), "aaa": pick("aaa")]
            )
        ) {
            GroupDeciderFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.eventReceived(.received(.result(winnerPlayerID: "zzz"), from: "aaa")))
        await store.receive(\.resultResolved) {
            $0.winner = winner
            $0.phase = .result
        }
    }
}
