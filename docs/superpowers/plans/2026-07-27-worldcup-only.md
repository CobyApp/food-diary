# World Cup Only + Online Voting World Cup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce the games to World Cup only, and turn the online mode into a timed voting World Cup (5 s per match, majority advances, host-authoritative).

**Architecture:** Task 1 deletes three solo games and simplifies the hub to two entries. Task 2 extends `MultiplayerMessage` and rewrites `GroupDeciderFeature` as a clock-driven voting bracket (tested with `TestClock`). Task 3 rebuilds `GroupDeciderView` for voting. Task 4 verifies everything.

**Tech Stack:** SwiftUI, TCA 1.26 (+`continuousClock`), GameKit (adapter unchanged), existing DesignSystem, iOS 18, Swift 6.

## Global Constraints

- **`WorldCupFeature` (solo) must not change** — its tests stay untouched and passing.
- The GameKit live adapter (`MultiplayerClient+GameKit.swift`) only needs the new message cases to compile; real behavior stays device-verified.
- Existing components only (`SoftCard`, `KitschIcon`, `KitschPressStyle`, `StickerTile`, `CutoutImage`, `PillButton`, `OutlineButton`, `ConfettiBurst`, `PaperBackground`, `L10n`). Korean copy → all four `Sources/FoodDiary/Resources/*.lproj/Localizable.strings`.
- Build `tuist build FeatureKit`; app `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' -skipMacroValidation`; tests `xcodebuild test ... -only-testing:<Bundle>/<Class> -skipMacroValidation`. Regenerate with `tuist generate --no-open` after adding/removing files. Never `tuist install`; never edit `Project.swift`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Task 1: Delete three games, simplify the hub to two entries

**Files:**
- Delete: `Sources/FeatureKit/Game/{GachaFeature,GachaView,RouletteFeature,RouletteView,CardFlipFeature,CardFlipView}.swift`
- Delete: `Tests/FeatureKitTests/{GachaFeatureTests,RouletteFeatureTests,CardFlipFeatureTests}.swift`
- Modify: `Sources/FeatureKit/Game/GameHubFeature.swift`
- Modify: `Sources/FeatureKit/Game/GameHubView.swift`
- Modify: `Tests/FeatureKitTests/GameHubFeatureTests.swift`

**Interfaces:**
- `GameKind` keeps only `case worldCup` (title 음식 월드컵 / symbol `crown.fill` / subtitle 끝까지 고르는 취향전 / minimum 2) — keep the enum + `CaseIterable` so the view can still iterate.
- `GameDestination` keeps only `case worldCup(WorldCupFeature)`.
- `GameHubFeature`'s actions stay the same shape (`gameTapped(GameKind)`, `game(PresentationAction<GameDestination.Action>)`, `groupTapped`, `groupDecider(...)`).

- [ ] **Step 1: Delete the six source files and three test files**

```bash
git rm Sources/FeatureKit/Game/GachaFeature.swift Sources/FeatureKit/Game/GachaView.swift \
       Sources/FeatureKit/Game/RouletteFeature.swift Sources/FeatureKit/Game/RouletteView.swift \
       Sources/FeatureKit/Game/CardFlipFeature.swift Sources/FeatureKit/Game/CardFlipView.swift \
       Tests/FeatureKitTests/GachaFeatureTests.swift Tests/FeatureKitTests/RouletteFeatureTests.swift \
       Tests/FeatureKitTests/CardFlipFeatureTests.swift
```

- [ ] **Step 2: Trim `GameHubFeature.swift`**

- `GameKind`: reduce to `case worldCup` and drop the other branches from `title`/`symbol`/`subtitle`/`minimum` (worldCup's `minimum` is 2).
- `GameDestination`: reduce to `case worldCup(WorldCupFeature)`.
- In `gameTapped`, the `switch kind` collapses to the single `worldCup` assignment.
- In the `game(...)` handling, remove the `.gacha`/`.cardFlip`/`.roulette` close cases, keeping `.game(.presented(.worldCup(.close)))` → `state.game = nil`.
- Leave the group-decider plumbing untouched.

- [ ] **Step 3: Rework `GameHubView.swift` into two entries**

Replace the solo `LazyVGrid` with a single full-width **혼자 월드컵** row (same shape as the existing group row: `SoftCard` + `KitschIcon("crown.fill", background: .appButter, size: 50)` + title/subtitle + chevron, lock badge when `store.cutouts.count < GameKind.worldCup.minimum`), keep the `sectionHeader`s ("혼자 결정" / "같이 결정"), keep the status strip, keep the staggered entrance (index 0 for solo, 0.28 delay for group), and keep both `fullScreenCover`s (the game one now only needs the `worldCup` case).

- [ ] **Step 4: Update `GameHubFeatureTests.swift`**

Keep `onAppear`/`groupTapped` tests. Change the "presents gacha" test to `test_gameTapped_presentsWorldCup`:
```swift
        await store.send(.gameTapped(.worldCup)) {
            $0.game = .worldCup(WorldCupFeature.State(cutouts: items))
        }
```
and the close test to `.game(.presented(.worldCup(.close)))` → `$0.game = nil`. (Seed `cutouts` with 2 items so the minimum passes.)

- [ ] **Step 5: Regenerate, build, run the affected tests**

Run: `tuist generate --no-open && tuist build FeatureKit`
Then: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/GameHubFeatureTests -only-testing:FeatureKitTests/WorldCupFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: `Build Succeeded`, `** TEST SUCCEEDED **` (WorldCup tests untouched and passing).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(game): keep only the world cup, hub becomes two entries

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Voting protocol + `GroupDeciderFeature` rewrite

**Files:**
- Modify: `Sources/ClientKit/Multiplayer/MultiplayerTypes.swift`
- Modify: `Sources/ClientKit/Multiplayer/MultiplayerClient+GameKit.swift` (only if it switches on message cases)
- Rewrite: `Sources/FeatureKit/Group/GroupDeciderFeature.swift`
- Rewrite: `Tests/FeatureKitTests/GroupDeciderFeatureTests.swift`
- Modify: `Tests/ClientKitTests/MultiplayerTypesTests.swift` (round-trip a new case)

**Interfaces:**
- `MultiplayerMessage` becomes:
```swift
public enum MultiplayerMessage: Equatable, Sendable, Codable {
    case menu(MenuPick)
    case bracket([String])                    // candidate order (playerIDs), from the host
    case pair(index: Int)                     // which match is live
    case vote(candidateID: String)            // a player's vote for the live match
    case roundResult(winnerID: String, leftVotes: Int, rightVotes: Int)
    case champion(String)
}
```
(`.result(winnerPlayerID:)` is removed.)
- `GroupDeciderFeature.State`: `phase: Phase` (`idle`/`authenticating`/`matchmaking`/`lobby`/`voting`/`reveal`/`champion`), `localPlayer`, `players`, `menus: [String: MenuPick]`, `myCutouts`, `order: [String]` (bracket order), `round: [String]` (current round's candidate ids), `pairIndex: Int`, `votes: [String: String]` (voterID→candidateID, current match only), `myVote: String?`, `secondsLeft: Int`, `lastTally: (winner: String, left: Int, right: Int)?` — expose as a small `Equatable` struct `Tally`, `championPick: MenuPick?`, `errorText: String?`.
  Computed: `isHost`, `allPlayerIDs`, `allSubmitted`, `currentPair: (MenuPick, MenuPick)?` (from `round[pairIndex]`, `round[pairIndex+1]`), `nextRoundSeeds`.
- `Action`: `onAppear`, `cutoutsLoaded`, `startTapped`, `authenticated`, `matchStarted`, `eventReceived(MultiplayerEvent)`, `cutoutPicked`, `menuBuilt(MenuPick)`, `voteTapped(String)`, `tick`, `hostTally`, `advance`, `failed(String)`, `leave`.
- `@Dependency(\.continuousClock)` drives the 5 s countdown (`tick` each second) and the ~1.5 s reveal hold.

- [ ] **Step 1: Extend the message enum + its round-trip test**

Add the new cases to `MultiplayerTypes.swift` (removing `.result`). In `Tests/ClientKitTests/MultiplayerTypesTests.swift`, replace the `.result` round-trip test with:
```swift
    func test_message_roundResult_codableRoundTrip() throws {
        let msg = MultiplayerMessage.roundResult(winnerID: "p1", leftVotes: 2, rightVotes: 1)
        let data = try JSONEncoder().encode(msg)
        XCTAssertEqual(try JSONDecoder().decode(MultiplayerMessage.self, from: data), msg)
    }

    func test_message_bracketAndVote_codableRoundTrip() throws {
        for msg in [MultiplayerMessage.bracket(["a", "b"]), .pair(index: 2), .vote(candidateID: "b"), .champion("a")] {
            let data = try JSONEncoder().encode(msg)
            XCTAssertEqual(try JSONDecoder().decode(MultiplayerMessage.self, from: data), msg)
        }
    }
```
Run them: `xcodebuild test ... -only-testing:ClientKitTests/MultiplayerTypesTests -skipMacroValidation`. Fix `MultiplayerClient+GameKit.swift` only if it pattern-matches removed cases.

- [ ] **Step 2: Write the failing reducer tests**

Replace `Tests/FeatureKitTests/GroupDeciderFeatureTests.swift` with tests that drive the flow directly (no live stream), using `TestClock`:
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
        await store.send(.startCountdown)          // if the reducer starts it on pair announcement, drive it explicitly here
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

        await store.send(.startCountdown)
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
```
> Implementer note: the exact action names for starting the countdown may differ from `.startCountdown` — implement the reducer first as designed, then align these tests to the real action set **without weakening the assertions** (bracket broadcast, vote recorded+sent, majority wins, tie→earlier, non-host champion). Give `State` a memberwise init exposing `phase`/`localPlayer`/`players`/`menus` (as today) plus mutable `order`/`round`/`pairIndex`.

- [ ] **Step 3: Rewrite `GroupDeciderFeature.swift`**

Implement the state machine per the spec:
- `.matchStarted` → `phase = .lobby` and start forwarding `multiplayer.events()`.
- `.cutoutPicked` → build `MenuPick` (unchanged logic: thumbnail + `mealByCutout` memo/place) → `.menuBuilt` stores it and sends `.menu`.
- After any `.menuBuilt` / `.eventReceived(.received(.menu…))` / `.playersChanged`: if `isHost && allSubmitted && order.isEmpty` → build `order` (sorted candidate ids for determinism), set `round = order`, `pairIndex = 0`, send `.bracket(order)` then `.pair(index: 0)`, `phase = .voting`, and start the countdown.
- Non-hosts apply `.bracket` / `.pair` from the host (setting `order`/`round`/`pairIndex`, clearing `votes`/`myVote`, `phase = .voting`, starting their own countdown display).
- `.voteTapped(id)` → guard `myVote == nil` and that `id` is in the current pair; set `myVote`, record in `votes[localPlayer.id]`, send `.vote(candidateID: id)`.
- `.eventReceived(.received(.vote(id), from: voter))` → `votes[voter] = id`.
- Countdown: a cancellable `.run` that ticks each second (`for await _ in clock.timer(interval: .seconds(1))`) sending `.tick`; `tick` decrements `secondsLeft`; when it reaches 0 the **host** sends `.hostTally`.
- `.hostTally` (host only) → count `votes` for each side; winner = more votes, else the candidate earlier in `order`; set `lastTally`, `phase = .reveal`, send `.roundResult(...)`; then after ~1.5 s (clock) send `.advance`.
- `.eventReceived(.received(.roundResult…))` (non-host) → set `lastTally`, `phase = .reveal` (host ignores its own echo).
- `.advance` (host) → append winner to the next round; when the current round is exhausted: if the next round has one candidate → `championPick`, `phase = .champion`, send `.champion(id)`; else `round = next`, `pairIndex = 0`, send `.pair(index: 0)`, `phase = .voting`, restart countdown. Odd counts: the trailing unpaired candidate advances automatically (bye).
- `.eventReceived(.received(.champion(id)))` → `championPick = menus[id]`, `phase = .champion`.
- `.leave` → `multiplayer.disconnect()`, reset state (keep `myCutouts`), cancel the countdown effect (use a `CancelID`).

- [ ] **Step 4: Tests green**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/GroupDeciderFeatureTests -only-testing:ClientKitTests/MultiplayerTypesTests -skipMacroValidation 2>&1 | tail -6`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(group): online world cup with 5-second majority voting

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `GroupDeciderView` — voting UI

**Files:**
- Rewrite: `Sources/FeatureKit/Group/GroupDeciderView.swift`

**Interfaces:** consumes the new `GroupDeciderFeature` state/actions only.

- [ ] **Step 1: Build the phase-driven UI**

- **start** (`idle`/`authenticating`/`matchmaking`): title 함께 월드컵 🏆, one-line explainer ("친구들과 5초 안에 투표해서 정해요"), `PillButton("게임센터로 시작")` / progress, `errorText` when present.
- **lobby**: participant count + who has submitted (`store.menus.count` / `allPlayerIDs.count`), and — until you've submitted — a grid of your cutouts (`StickerTile` + `CutoutImage`, `KitschPressStyle`) sending `.cutoutPicked`; after submitting show "제출 완료! 다른 사람들을 기다리는 중… ⏳".
- **voting**: the round label (`round.count`강 / 결승), a **countdown ring** (`Circle().trim(from: 0, to: secondsLeft/5)` with `.appCherry`, plus the number in the middle), and the pair as two big tappable cards (thumbnail via `CutoutImage(data:)`, place name, memo) sending `.voteTapped`. The chosen side gets a selected ring; both dim once `myVote != nil`. Show `votes.count` / participants as "N명 투표".
- **reveal**: keep both cards, overlay each with its vote count, highlight the winner (scale + `ConfettiBurst` on the winner side), hold briefly (the reducer drives the timing).
- **champion**: the winner's thumbnail big, "오늘은 ○○님의 [가게]!", memo, and `PillButton("나가기")` → `.leave`.
- Close control (`xmark.circle.fill`) → `.leave` in every phase.
- New Korean copy → all four `.lproj` files.

- [ ] **Step 2: Build**

Run: `tuist generate --no-open && tuist build FeatureKit`
Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat(group): voting world cup UI with countdown ring and tally reveal

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Full verification

- [ ] **Step 1: App build + full suite**

Run: `tuist generate --no-open && tuist build FeatureKit`
App: `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' -skipMacroValidation 2>&1 | tail -3`
Full suite: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -skipMacroValidation 2>&1 | tail -6`
Expected: `Build Succeeded`, `BUILD SUCCEEDED`, `** TEST SUCCEEDED **`. The deleted games' tests are gone; `WorldCupFeatureTests` and everything else pass unchanged.

- [ ] **Step 2: Confirm no dangling references**

Run: `grep -rn "Gacha\|Roulette\|CardFlip" Sources/ Tests/ || echo clean`
Expected: `clean` (no references to the removed games anywhere, including `L10n` keys used only by them — remove those keys from the four `.lproj` files if they are now unused).

- [ ] **Step 3: Commit any cleanup**

```bash
git add -A
git commit -m "chore: drop strings left over from the removed games

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review Notes (against spec)

- **Spec §2 solo simplification** (delete 3 games, hub = two full-width entries, GameKind/GameDestination collapse) → Task 1 (+ updated hub tests, WorldCup untouched).
- **Spec §3 online voting** (submit → host bracket → 5 s vote → tally/tie rule → advance → champion, host-authoritative, `continuousClock`) → Task 2 with five reducer tests incl. the tie rule and the non-host path.
- **Spec §3 protocol** (`bracket`/`pair`/`vote`/`roundResult`/`champion`, `.result` removed) → Task 2 Step 1 + Codable tests.
- **Spec §4/§5** → Task 3 (view) and Task 4 (full suite + no dangling references).

## Notes for the implementer

- Always `-skipMacroValidation`. Booted sim UDID `3B1E5795-617D-4955-8048-0CC8AD03BE95`.
- `WorldCupFeature`/`WorldCupView` (solo) are off-limits — do not edit them.
- Use `@Dependency(\.continuousClock)` (never `Task.sleep` with wall time) so the countdown is testable, and cancel it via a `CancelID` on `.leave`/phase changes.
- Determinism: bracket order is `menus.keys.sorted()`; ties resolve by position in `order`. No `Math.random`/`Date()` in the reducer.
- The GameKit adapter may need trivial edits only if it switches on removed message cases.
