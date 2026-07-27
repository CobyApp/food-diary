# Game Center Group Decider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Game Center multiplayer decider — friends match, each submits a menu from their cutouts (with memo + restaurant), and a synchronized roulette picks the group's meal.

**Architecture:** New `MultiplayerClient` (ClientKit, GameKit-backed, fully encapsulating GameKit so the reducer is mockable). `GroupDeciderFeature` (FeatureKit) is the TestStore-tested state machine. Views + the GameKit live adapter are compile-verified only (device testing by the user). Entry from the GameHub.

**Tech Stack:** SwiftUI + GameKit, TCA 1.26, pastel DesignSystem, iOS 18, Swift 6.

## Global Constraints

- The reducer must touch ONLY `MultiplayerClient`/`RandomClient`/`PersistenceClient` — never GameKit types — so it stays mockable/testable. Randomness only via `RandomClient`.
- GameKit real-time cannot be tested in the simulator: the live adapter + views are **compile-verified only**; the reducer is the tested brain (mock client). The user verifies real matches on 2 devices and enables Game Center in App Store Connect.
- Korean UI strings; English comments; light mode; pastel DesignSystem.
- Build module `tuist build FeatureKit` / `tuist build ClientKit`; tests `xcodebuild test ... -only-testing:<Bundle>/<Class> -skipMacroValidation`; app build via `FoodDiary` scheme with `-skipMacroValidation`. Regenerate after adding files. Never `tuist install`. **`Project.swift` IS edited once** (Task 5, Game Center entitlement) — the only allowed change.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Task 1: Multiplayer types + Codable test

**Files:**
- Create: `Sources/ClientKit/Multiplayer/MultiplayerTypes.swift`
- Test: `Tests/ClientKitTests/MultiplayerTypesTests.swift`

**Interfaces:**
- Produces: `LocalPlayer`, `RemotePlayer`, `MenuPick` (Codable), `MultiplayerMessage` (Codable), `MultiplayerEvent`.

- [ ] **Step 1: Write the failing test**

`Tests/ClientKitTests/MultiplayerTypesTests.swift`:
```swift
import XCTest
@testable import ClientKit

final class MultiplayerTypesTests: XCTestCase {
    func test_message_menu_codableRoundTrip() throws {
        let pick = MenuPick(playerID: "p1", playerName: "코비", thumbnail: Data([1, 2, 3]),
                            memo: "존맛", placeName: "라멘집", address: "후쿠오카 1-2")
        let msg = MultiplayerMessage.menu(pick)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(MultiplayerMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
    }

    func test_message_result_codableRoundTrip() throws {
        let msg = MultiplayerMessage.result(winnerPlayerID: "p2")
        let data = try JSONEncoder().encode(msg)
        XCTAssertEqual(try JSONDecoder().decode(MultiplayerMessage.self, from: data), msg)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:ClientKitTests/MultiplayerTypesTests -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — `cannot find 'MenuPick'`.

- [ ] **Step 3: Write `MultiplayerTypes.swift`**

```swift
import Foundation

public struct LocalPlayer: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public init(id: String, displayName: String) { self.id = id; self.displayName = displayName }
}

public struct RemotePlayer: Equatable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public init(id: String, displayName: String) { self.id = id; self.displayName = displayName }
}

public struct MenuPick: Equatable, Sendable, Codable, Identifiable {
    public var id: String { playerID }
    public let playerID: String
    public let playerName: String
    public let thumbnail: Data
    public let memo: String
    public let placeName: String
    public let address: String
    public init(playerID: String, playerName: String, thumbnail: Data,
                memo: String, placeName: String, address: String) {
        self.playerID = playerID; self.playerName = playerName; self.thumbnail = thumbnail
        self.memo = memo; self.placeName = placeName; self.address = address
    }
}

public enum MultiplayerMessage: Equatable, Sendable, Codable {
    case menu(MenuPick)
    case result(winnerPlayerID: String)
}

public enum MultiplayerEvent: Equatable, Sendable {
    case playersChanged([RemotePlayer])
    case received(MultiplayerMessage, from: String)
    case matchEnded
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:ClientKitTests/MultiplayerTypesTests -skipMacroValidation 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClientKit/Multiplayer/MultiplayerTypes.swift Tests/ClientKitTests/MultiplayerTypesTests.swift
git commit -m "feat(clientkit): multiplayer types + message protocol

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `MultiplayerClient` (interface + mock + GameKit live adapter)

**Files:**
- Create: `Sources/ClientKit/Multiplayer/MultiplayerClient.swift`
- Create: `Sources/ClientKit/Multiplayer/MultiplayerClient+GameKit.swift`

**Interfaces:**
- Consumes: Task 1 types.
- Produces: `@DependencyClient struct MultiplayerClient` with `authenticate`,
  `startMatch`, `events`, `send`, `disconnect`; `DependencyValues.multiplayer`;
  `testValue`/`previewValue`; and a GameKit `liveValue` (compile-verified only).

- [ ] **Step 1: Write `MultiplayerClient.swift`** (interface + mock)

```swift
import Dependencies
import DependenciesMacros

public enum MultiplayerError: Error, Equatable { case notAuthenticated, matchmakingCancelled, noMatch }

@DependencyClient
public struct MultiplayerClient: Sendable {
    public var authenticate: @Sendable () async throws -> LocalPlayer
    public var startMatch: @Sendable () async throws -> Void
    public var events: @Sendable () -> AsyncStream<MultiplayerEvent> = { .finished }
    public var send: @Sendable (_ message: MultiplayerMessage) async throws -> Void
    public var disconnect: @Sendable () -> Void
}

extension MultiplayerClient: TestDependencyKey {
    public static let testValue = MultiplayerClient()
    public static let previewValue = MultiplayerClient(
        authenticate: { LocalPlayer(id: "me", displayName: "나") },
        startMatch: {},
        events: { .finished },
        send: { _ in },
        disconnect: {}
    )
}

public extension DependencyValues {
    var multiplayer: MultiplayerClient {
        get { self[MultiplayerClient.self] }
        set { self[MultiplayerClient.self] = newValue }
    }
}
```

- [ ] **Step 2: Write `MultiplayerClient+GameKit.swift`** (live adapter — compile-verified only)

```swift
#if canImport(GameKit) && !targetEnvironment(simulator)
import GameKit
#else
import GameKit
#endif
import UIKit
import Dependencies

// Live GameKit adapter. NOTE: real behavior is verifiable only on device with
// Game Center accounts — this compiles and follows GameKit conventions but is
// expected to need on-device iteration.
final class GameCenterCoordinator: NSObject, GKMatchDelegate, GKMatchmakerViewControllerDelegate, @unchecked Sendable {
    static let shared = GameCenterCoordinator()

    private var match: GKMatch?
    private let (stream, continuation) = AsyncStream<MultiplayerEvent>.makeStream()
    private var matchmakeContinuation: CheckedContinuation<Void, Error>?

    func eventStream() -> AsyncStream<MultiplayerEvent> { stream }

    func authenticate() async throws -> LocalPlayer {
        if GKLocalPlayer.local.isAuthenticated {
            return LocalPlayer(id: GKLocalPlayer.local.gamePlayerID, displayName: GKLocalPlayer.local.displayName)
        }
        return try await withCheckedThrowingContinuation { cont in
            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
                if let viewController {
                    Task { @MainActor in self?.topViewController()?.present(viewController, animated: true) }
                    return
                }
                if GKLocalPlayer.local.isAuthenticated {
                    cont.resume(returning: LocalPlayer(id: GKLocalPlayer.local.gamePlayerID,
                                                       displayName: GKLocalPlayer.local.displayName))
                } else {
                    cont.resume(throwing: error ?? MultiplayerError.notAuthenticated)
                }
                GKLocalPlayer.local.authenticateHandler = nil
            }
        }
    }

    @MainActor
    func startMatch() async throws {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 4
        guard let vc = GKMatchmakerViewController(matchRequest: request) else { throw MultiplayerError.noMatch }
        vc.matchmakerDelegate = self
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.matchmakeContinuation = cont
            topViewController()?.present(vc, animated: true)
        }
    }

    func send(_ message: MultiplayerMessage) throws {
        guard let match, let data = try? JSONEncoder().encode(message) else { return }
        try match.sendData(toAllPlayers: match.players, with: .reliable)
        _ = data // encoded payload sent below
    }

    func disconnect() { match?.disconnect(); match = nil }

    // MARK: GKMatchmakerViewControllerDelegate
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        viewController.dismiss(animated: true)
        matchmakeContinuation?.resume(throwing: MultiplayerError.matchmakingCancelled)
        matchmakeContinuation = nil
    }
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        viewController.dismiss(animated: true)
        matchmakeContinuation?.resume(throwing: error)
        matchmakeContinuation = nil
    }
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        viewController.dismiss(animated: true)
        match.delegate = self
        self.match = match
        emitPlayers()
        matchmakeContinuation?.resume(returning: ())
        matchmakeContinuation = nil
    }

    // MARK: GKMatchDelegate
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        if let msg = try? JSONDecoder().decode(MultiplayerMessage.self, from: data) {
            continuation.yield(.received(msg, from: player.gamePlayerID))
        }
    }
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        emitPlayers()
        if match.expectedPlayerCount == 0 { /* all connected */ }
    }

    private func emitPlayers() {
        let players = (match?.players ?? []).map { RemotePlayer(id: $0.gamePlayerID, displayName: $0.displayName) }
        continuation.yield(.playersChanged(players))
    }

    @MainActor private func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

extension MultiplayerClient: DependencyKey {
    public static let liveValue: MultiplayerClient = {
        let coordinator = GameCenterCoordinator.shared
        return MultiplayerClient(
            authenticate: { try await coordinator.authenticate() },
            startMatch: { try await coordinator.startMatch() },
            events: { coordinator.eventStream() },
            send: { message in try coordinator.send(message) },
            disconnect: { coordinator.disconnect() }
        )
    }()
}
```
> **Implementer note:** This adapter is the compile-verified GameKit boundary; it may need on-device iteration (e.g. `match.send` payload wiring, authenticateHandler re-entrancy, `sendData` actually forwarding the encoded `data`). Fix the obvious `send` bug so the encoded `data` is what's sent: `try match.sendData(toAllPlayers: match.players, with: .reliable)` must send `data` — use `match.send(data, to: match.players, dataMode: .reliable)` if the SDK spelling differs. Keep the interface identical; only make it compile cleanly.

- [ ] **Step 3: Build to verify it compiles**

Run: `tuist generate --no-open && tuist build ClientKit`
Expected: `Build Succeeded`. (Resolve any GameKit API-spelling issues so it compiles; do not change the `MultiplayerClient` interface.)

- [ ] **Step 4: Commit**

```bash
git add Sources/ClientKit/Multiplayer/MultiplayerClient.swift Sources/ClientKit/Multiplayer/MultiplayerClient+GameKit.swift
git commit -m "feat(clientkit): MultiplayerClient (mock + GameKit live adapter)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `GroupDeciderFeature` reducer + tests

**Files:**
- Create: `Sources/FeatureKit/Group/GroupDeciderFeature.swift`
- Test: `Tests/FeatureKitTests/GroupDeciderFeatureTests.swift`

**Interfaces:**
- Consumes: `MultiplayerClient` (`\.multiplayer`), `RandomClient` (`\.random`),
  `PersistenceClient` (`\.persistence`), `CutoutSnapshot`, `ImageStore`, the Task-1 types.
- Produces: `@Reducer struct GroupDeciderFeature` with the phase state machine and
  `menuBuilt`/`eventReceived`/host-winner logic. `RandomClient` needs a `pickMenu`
  helper — reuse `random.pick` by adapting, OR add a menu picker. To avoid changing
  `RandomClient`, the host picks with `random.shuffled(cutouts)` style is N/A here;
  instead add a tiny local pick: use `@Dependency(\.withRandomNumberGenerator)`? No —
  keep testable: host winner = element at `random`-provided index. Define the pick as
  `menus.values` shuffled by a new `RandomClient.shuffledMenus`? Simpler: reuse the
  existing `random` by picking from the player-id array — see Step 3.

- [ ] **Step 1: Write the failing tests**

`Tests/FeatureKitTests/GroupDeciderFeatureTests.swift`:
```swift
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
```
> Note: give `State` a memberwise `init` exposing `phase`, `localPlayer`, `players`, `menus` for the tests. `random.pick(items.first)` with `items` = the menus' player IDs (Step 3) makes "aaa" the winner deterministically.

- [ ] **Step 2: Run to verify it fails**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/GroupDeciderFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — `cannot find 'GroupDeciderFeature'`.

- [ ] **Step 3: Write `GroupDeciderFeature.swift`**

```swift
import ComposableArchitecture
import Foundation
import Models
import ClientKit

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
            self.phase = phase; self.localPlayer = localPlayer; self.players = players
            self.menus = menus; self.myCutouts = myCutouts; self.winner = winner
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
                    } catch { await send(.failed("게임센터 로그인이 필요해요")) }
                }

            case let .authenticated(me):
                state.localPlayer = me
                state.phase = .matchmaking
                return .run { send in
                    do {
                        try await multiplayer.startMatch()
                        await send(.matchStarted)
                    } catch { await send(.failed("매칭이 취소됐어요")) }
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
                    return maybeRunHost(&state)
                case let .received(.menu(pick), _):
                    state.menus[pick.playerID] = pick
                    return maybeRunHost(&state)
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
                    let data = ImageStore.disk(directory: ImageStore.cutoutsDirectory).load(cutout.fileName) ?? Data()
                    let thumb = GroupDeciderFeature.thumbnail(from: data)
                    let pick = MenuPick(
                        playerID: me.id, playerName: me.displayName, thumbnail: thumb,
                        memo: meal?.memo ?? "", placeName: meal?.place?.name ?? "",
                        address: meal?.place?.address ?? ""
                    )
                    await send(.menuBuilt(pick))
                }

            case let .menuBuilt(pick):
                state.menus[pick.playerID] = pick
                let effect: Effect<Action> = .run { _ in try? await multiplayer.send(.menu(pick)) }
                return .merge(effect, maybeRunHost(&state))

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
    // (via RandomClient over the submitted player IDs) and broadcast it.
    private func maybeRunHost(_ state: inout State) -> Effect<Action> {
        guard state.isHost, state.allSubmitted, state.winner == nil else { return .none }
        let ids = state.menus.keys.sorted().map { CutoutSnapshot(id: UUID(), fileName: $0, createdAt: Date(), label: $0) }
        // Reuse RandomClient.pick over placeholder snapshots whose fileName carries
        // the playerID, so selection is injectable/deterministic in tests.
        let winnerID = random.pick(ids)?.fileName ?? state.menus.keys.sorted().first
        guard let winnerID, let winner = state.menus[winnerID] else { return .none }
        state.winner = winner
        state.phase = .result
        return .run { _ in try? await multiplayer.send(.result(winnerPlayerID: winnerID)) }
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

import UIKit
```
> Note: the `maybeRunHost` winner-pick reuses `RandomClient.pick` by wrapping player IDs in placeholder `CutoutSnapshot`s (fileName = playerID). In tests `$0.random.pick = { $0.first }` makes the lexicographically-first submitted ID win deterministically. `thumbnail(from:)` uses UIKit (`import UIKit`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/GroupDeciderFeatureTests -skipMacroValidation 2>&1 | tail -6`
Expected: `** TEST SUCCEEDED **` (3 tests). If a `.receive` for `resultResolved` needs the exact winner, the test asserts `$0.winner`/`$0.phase` with exhaustivity off.

- [ ] **Step 5: Commit**

```bash
git add Sources/FeatureKit/Group/GroupDeciderFeature.swift Tests/FeatureKitTests/GroupDeciderFeatureTests.swift
git commit -m "feat(featurekit): GroupDeciderFeature reducer (mock-tested)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: `GroupDeciderView`

**Files:**
- Create: `Sources/FeatureKit/Group/GroupDeciderView.swift`

**Interfaces:**
- Consumes: `GroupDeciderFeature`, DesignSystem (`ScreenScaffold`? no — full-screen; use tokens + `SoftCard`/`PillButton`/`StickerTile`), `CutoutImage`.
- Produces: `public struct GroupDeciderView: View { init(store:) }`.

- [ ] **Step 1: Write the file**

```swift
import SwiftUI
import ComposableArchitecture
import Models

public struct GroupDeciderView: View {
    @Bindable var store: StoreOf<GroupDeciderFeature>
    public init(store: StoreOf<GroupDeciderFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 10)]

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            switch store.phase {
            case .idle, .authenticating, .matchmaking:
                startScreen
            case .lobby:
                lobby
            case .result:
                resultScreen
            }
            closeButton
        }
        .task { store.send(.onAppear) }
    }

    private var startScreen: some View {
        VStack(spacing: 18) {
            Text("함께 정하기 🎉").font(.appDisplay).foregroundStyle(.appInk)
            Text("친구를 초대해서 다 같이\n오늘 뭐 먹을지 정해요")
                .font(.appBody).foregroundStyle(.appMuted).multilineTextAlignment(.center)
            if let err = store.errorText {
                Text(err).font(.appCaption).foregroundStyle(.appPinkInk)
            }
            if store.phase == .idle {
                PillButton("게임센터로 시작") { store.send(.startTapped) }.padding(.horizontal, 60)
            } else {
                ProgressView().tint(.appBlue)
            }
        }
        .padding(24)
    }

    private var lobby: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("메뉴 고르기").font(.appTitle).foregroundStyle(.appInk)
            Text("참가자 \(store.allPlayerIDs.count)명 · 제출 \(store.menus.count)명")
                .font(.appCaption).foregroundStyle(.appMuted)
            if store.mySubmitted {
                Text("제출 완료! 다른 사람들을 기다리는 중… ⏳").font(.appBody).foregroundStyle(.appBlueInk)
            } else {
                Text("내 누끼에서 먹고 싶은 메뉴를 골라요").font(.appBody).foregroundStyle(.appMuted)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(store.myCutouts) { c in
                            Button { store.send(.cutoutPicked(c)) } label: {
                                StickerTile(tint: .rotating(c.id.hashValue)) { CutoutImage(fileName: c.fileName) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(24)
    }

    private var resultScreen: some View {
        VStack(spacing: 16) {
            Text("오늘의 선택 🎉").font(.appTitle).foregroundStyle(.appInk)
            if let w = store.winner {
                StickerTile(tint: .pink) { CutoutImage(data: w.thumbnail) }
                    .frame(width: 200, height: 200)
                Text("\(w.playerName)님의 \(w.placeName.isEmpty ? "메뉴" : w.placeName)")
                    .font(.appDisplay).foregroundStyle(.appBlueInk).multilineTextAlignment(.center)
                if !w.memo.isEmpty {
                    Text("\u{201C}\(w.memo)\u{201D}").font(.appBody).foregroundStyle(.appInk)
                }
                if !w.address.isEmpty {
                    Text(w.address).font(.appCaption).foregroundStyle(.appMuted)
                }
            }
            PillButton("나가기") { store.send(.leave) }.padding(.horizontal, 60)
        }
        .padding(24)
    }

    private var closeButton: some View {
        Button { store.send(.leave) } label: {
            Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.appMuted)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(20)
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `tuist generate --no-open && tuist build FeatureKit`
Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add Sources/FeatureKit/Group/GroupDeciderView.swift
git commit -m "feat(featurekit): GroupDeciderView (start/lobby/result)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: GameHub entry + Game Center entitlement + full verification

**Files:**
- Modify: `Sources/FeatureKit/Game/GameHubFeature.swift`
- Modify: `Sources/FeatureKit/Game/GameHubView.swift`
- Modify: `Tests/FeatureKitTests/GameHubFeatureTests.swift`
- Modify: `Project.swift` (Game Center entitlement — the one allowed change)

**Interfaces:**
- GameHubFeature gains `@Presents var groupDecider: GroupDeciderFeature.State?`,
  `Action.groupTapped`, `Action.groupDecider(PresentationAction<GroupDeciderFeature.Action>)`,
  and `.ifLet(\.$groupDecider, action: \.groupDecider) { GroupDeciderFeature() }`.

- [ ] **Step 1: Add the failing test**

Append to `Tests/FeatureKitTests/GameHubFeatureTests.swift`:
```swift
    @MainActor
    func test_groupTapped_presentsGroupDecider() async {
        let store = TestStore(initialState: GameHubFeature.State()) {
            GameHubFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.groupTapped) {
            $0.groupDecider = GroupDeciderFeature.State()
        }
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/GameHubFeatureTests/test_groupTapped_presentsGroupDecider -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — no member `groupTapped`.

- [ ] **Step 3: Extend `GameHubFeature.swift`**

Add to `State`: `@Presents public var groupDecider: GroupDeciderFeature.State?`.
Add to `Action`:
```swift
        case groupTapped
        case groupDecider(PresentationAction<GroupDeciderFeature.Action>)
```
In the `Reduce` switch add:
```swift
            case .groupTapped:
                state.groupDecider = GroupDeciderFeature.State()
                return .none
            case .groupDecider(.presented(.leave)):
                state.groupDecider = nil
                return .none
            case .groupDecider:
                return .none
```
Add after the existing `.ifLet(\.$game, ...)`:
```swift
        .ifLet(\.$groupDecider, action: \.groupDecider) {
            GroupDeciderFeature()
        }
```
> Keep `GameHubFeature.Action` non-Equatable if it already is (it is not required Equatable — the existing enum has no Equatable). If the existing `game` `PresentationAction` compiled, `groupDecider` will too.

- [ ] **Step 4: Extend `GameHubView.swift`**

Add a "함께 정하기 🎉" card to the grid (after the four `GameKind` cards):
```swift
            Button { store.send(.groupTapped) } label: {
                SoftCard {
                    VStack(spacing: 8) {
                        Text("🎉").font(.system(size: 44))
                        Text("함께 정하기").font(.appSection).foregroundStyle(.appInk)
                        Text("게임센터").font(.appCaption).foregroundStyle(.appMuted)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
            }
            .buttonStyle(.plain)
```
Add a second `fullScreenCover` (after the existing game one):
```swift
        .fullScreenCover(item: $store.scope(state: \.groupDecider, action: \.groupDecider)) { groupStore in
            GroupDeciderView(store: groupStore)
        }
```

- [ ] **Step 5: Add the Game Center entitlement in `Project.swift`**

On the `FoodDiary` app target, add an `entitlements:` argument:
```swift
            entitlements: .dictionary([
                "com.apple.developer.game-center": .boolean(true)
            ]),
```
(Place it alongside `infoPlist:`/`sources:`. This is the single allowed `Project.swift` edit.)

- [ ] **Step 6: Build module + app + full suite**

Run: `tuist generate --no-open && tuist build FeatureKit`
App: `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' -skipMacroValidation 2>&1 | tail -3`
Full suite: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -skipMacroValidation 2>&1 | tail -6`
Expected: `Build Succeeded`, `BUILD SUCCEEDED`, `** TEST SUCCEEDED **` (existing GameHubFeatureTests + all others still pass).

- [ ] **Step 7: Commit**

```bash
git add Sources/FeatureKit/Game/GameHubFeature.swift Sources/FeatureKit/Game/GameHubView.swift Tests/FeatureKitTests/GameHubFeatureTests.swift Project.swift
git commit -m "feat: add 함께 정하기 (group decider) to game hub + game center entitlement

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review Notes (against spec)

- **Spec §3 types/protocol** → Task 1 (+ Codable test). Enriched `MenuPick` carries thumbnail + memo + placeName + address.
- **Spec §4 MultiplayerClient (mock + GameKit)** → Task 2 (interface/mock tested-by-use; live compile-only).
- **Spec §5 GroupDeciderFeature state machine + host authority** → Task 3 (3 TestStore tests: auth→lobby, host roulette+broadcast, non-host result).
- **Spec §5 menu built from cutout (memo+place, thumbnail)** → Task 3 `cutoutPicked`/`menuBuilt`.
- **Spec §6 views + GameHub entry** → Task 4 + Task 5. **§7 entitlement** → Task 5 Step 5.
- **Spec §8 testing** → reducer tests + Codable test; views/GameKit build-verified; device testing by the user.

## Notes for the implementer

- Always `-skipMacroValidation`. Booted sim UDID `3B1E5795-617D-4955-8048-0CC8AD03BE95` (else `xcrun simctl list devices booted`).
- The GameKit live adapter (Task 2) is compile-verified only — make it COMPILE cleanly (fix GameKit API spellings, ensure `send` transmits the encoded `data`), do not change the `MultiplayerClient` interface, and do not attempt to run a real match.
- Do not change other reducers'/tests' behavior. If `MealSnapshot`/`CutoutSnapshot` unresolved in a file, add `import Models`.
- `Project.swift` entitlement is the only allowed Project.swift edit; if `.dictionary`/`.boolean` entitlement spelling differs in this Tuist version, adapt to the correct `Entitlements` API so it generates.
