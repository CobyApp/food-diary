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

    /// Host with two submitted menus: bracket + first pair are broadcast.
    @MainActor
    func test_hostStartsBracketWhenAllSubmitted() async {
        let sent = LockIsolatedBox()
        let store = TestStore(
            initialState: GroupDeciderFeature.State(
                phase: .lobby,
                localPlayer: LocalPlayer(id: "aaa", displayName: "나"),
                players: [RemotePlayer(id: "zzz", displayName: "친구")],
                menus: ["aaa": pick("aaa")]
            )
        ) {
            GroupDeciderFeature()
        } withDependencies: {
            $0.continuousClock = TestClock()
            $0.multiplayer.send = { sent.append($0) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.eventReceived(.received(.menu(pick("zzz")), from: "zzz")))
        XCTAssertEqual(store.state.phase, .voting)
        XCTAssertEqual(store.state.round, ["aaa", "zzz"])
        XCTAssertTrue(sent.values.contains(.bracket(["aaa", "zzz"])))
        XCTAssertTrue(sent.values.contains(.pair(index: 0)))
    }

    /// A vote is recorded locally and sent to the others.
    @MainActor
    func test_voteRecordedAndSent() async {
        let sent = LockIsolatedBox()
        let store = TestStore(initialState: votingState()) {
            GroupDeciderFeature()
        } withDependencies: {
            $0.continuousClock = TestClock()
            $0.multiplayer.send = { sent.append($0) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.voteTapped("zzz"))
        XCTAssertEqual(store.state.myVote, "zzz")
        XCTAssertTrue(sent.values.contains(.vote(candidateID: "zzz")))
    }

    /// After 5 seconds the host tallies; the majority advances and is broadcast.
    @MainActor
    func test_hostTalliesAfterCountdown_majorityWins() async {
        let clock = TestClock()
        let sent = LockIsolatedBox()
        let store = TestStore(initialState: votingState()) {
            GroupDeciderFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.multiplayer.send = { sent.append($0) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        // Friend votes for "zzz"; we vote for "zzz" too -> zzz wins 2-0.
        await store.send(.eventReceived(.received(.vote(candidateID: "zzz"), from: "zzz")))
        await store.send(.voteTapped("zzz"))
        // Drive the countdown effect explicitly: the reducer starts it internally
        // whenever a pair is (re-)applied via `.eventReceived(.received(.pair...))`
        // (both for a non-host applying the host's broadcast and, here, to kick off
        // the timer on a hand-built `.voting` state without going through the full
        // bracket-building flow). Re-announcing the same live pair (index 0) is a
        // no-op on `round`/`votes` since the pair is unchanged.
        await store.send(.eventReceived(.received(.pair(index: 0), from: "aaa")))
        await clock.advance(by: .seconds(5))
        await store.receive(\.hostTally)
        XCTAssertEqual(store.state.lastTally?.winner, "zzz")
        XCTAssertTrue(sent.values.contains { if case .roundResult(let w, _, _) = $0 { return w == "zzz" } else { return false } })
    }

    /// Tie (or no votes) -> the candidate earlier in the bracket order wins.
    @MainActor
    func test_tieGoesToEarlierCandidate() async {
        let clock = TestClock()
        let store = TestStore(initialState: votingState()) {
            GroupDeciderFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.multiplayer.send = { _ in }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.eventReceived(.received(.pair(index: 0), from: "aaa")))
        await clock.advance(by: .seconds(5))
        await store.receive(\.hostTally)
        XCTAssertEqual(store.state.lastTally?.winner, "aaa")   // no votes -> earlier wins
    }

    /// A non-host simply applies the champion it is told about.
    @MainActor
    func test_nonHostAppliesChampion() async {
        var state = votingState()
        state.localPlayer = LocalPlayer(id: "zzz", displayName: "나")   // not the host
        let store = TestStore(initialState: state) { GroupDeciderFeature() } withDependencies: {
            $0.continuousClock = TestClock()
            $0.multiplayer.send = { _ in }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.eventReceived(.received(.champion("aaa"), from: "aaa")))
        XCTAssertEqual(store.state.phase, .champion)
        XCTAssertEqual(store.state.championPick?.playerID, "aaa")
    }

    private func votingState() -> GroupDeciderFeature.State {
        var state = GroupDeciderFeature.State(
            phase: .voting,
            localPlayer: LocalPlayer(id: "aaa", displayName: "나"),
            players: [RemotePlayer(id: "zzz", displayName: "친구")],
            menus: ["aaa": pick("aaa"), "zzz": pick("zzz")]
        )
        state.order = ["aaa", "zzz"]
        state.round = ["aaa", "zzz"]
        state.pairIndex = 0
        return state
    }
}

/// Tiny lock-backed collector (ConcurrencyExtras' LockIsolated isn't linked here).
private final class LockIsolatedBox: @unchecked Sendable {
    private var storage: [MultiplayerMessage] = []
    private let lock = NSLock()
    func append(_ value: MultiplayerMessage) { lock.lock(); storage.append(value); lock.unlock() }
    var values: [MultiplayerMessage] { lock.lock(); defer { lock.unlock() }; return storage }
}
