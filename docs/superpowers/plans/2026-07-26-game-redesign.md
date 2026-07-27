# Game Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Card Flip becomes "pick one card, done" (as originally specced), Roulette becomes a real circular wheel, and the Gacha lever becomes a turnable gachapon dial.

**Architecture:** Task 1 simplifies `CardFlipFeature` (the only reducer/test change). Tasks 2–3 are view-only rebuilds of `RouletteView`'s wheel and `GachaView`'s dial, reusing the reducers' existing winner contract (`reel` + `landingIndex`).

**Tech Stack:** SwiftUI, TCA 1.26, existing kitsch/pastel DesignSystem, iOS 18, Swift 6.

## Global Constraints

- **Only Task 1 touches a reducer/tests.** Tasks 2–3 must not edit any reducer/state/action or any test.
- **Read each file fully before editing; edit SURGICALLY.** Preserve existing components and behavior not named in the task (`SoftCard`, `KitschIcon`, `KitschSparkle`, `ConfettiBurst`, `WashiTape`, `PaperBackground`, `KitschPressStyle`, `PillButton`, `OutlineButton`, `KitschLoadingView`, `L10n`, haptics, `ResultCard` hand-off). Don't invent components.
- Deterministic animation math (index/angle-based); no `Math.random`/`Date()`.
- Korean UI + `L10n`; any new copy goes into all four `Sources/FoodDiary/Resources/*.lproj/Localizable.strings`.
- Build `tuist build FeatureKit`; app `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' -skipMacroValidation`; tests `xcodebuild test ... -only-testing:<Bundle>/<Class> -skipMacroValidation`. Never `tuist install`; never edit `Project.swift`. Always `-skipMacroValidation`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Task 1: Card Flip — pick one card, done

**Files:**
- Modify: `Sources/FeatureKit/Game/CardFlipFeature.swift`
- Modify: `Sources/FeatureKit/Game/CardFlipView.swift`
- Rewrite: `Tests/FeatureKitTests/CardFlipFeatureTests.swift`

**Interfaces:**
- `State`: `cutouts`, `cards: [CutoutSnapshot]`, `revealedIndex: Int?`, `resultInfo: GameResultInfo?`, computed `result: CutoutSnapshot?`. (Removed: `firstRevealedIndex`, `secondRevealedIndex`, `moves`, `revealedIndices`.)
- `Action`: `start`, `flip(Int)`, `infoLoaded(GameResultInfo?)`, `playAgain`, `close`. (Removed: `hideMismatch`.)

- [ ] **Step 1: Rewrite the tests to the intended behavior**

Replace the whole body of `Tests/FeatureKitTests/CardFlipFeatureTests.swift` with:
```swift
import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class CardFlipFeatureTests: XCTestCase {
    private func snap(_ n: Int) -> CutoutSnapshot {
        CutoutSnapshot(id: UUID(), fileName: "\(n).png", createdAt: Date(), label: "f\(n)")
    }

    @MainActor
    func test_start_laysDistinctCards() async {
        let items = [snap(1), snap(2), snap(3)]
        let store = TestStore(initialState: CardFlipFeature.State(cutouts: items)) {
            CardFlipFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.start) { $0.cards = items }
        XCTAssertEqual(store.state.cards.count, 3)          // distinct, not doubled
        XCTAssertNil(store.state.result)
    }

    @MainActor
    func test_flip_selectsThatCardAsResult() async {
        let items = [snap(1), snap(2), snap(3)]
        let store = TestStore(initialState: CardFlipFeature.State(cutouts: items)) {
            CardFlipFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.start)
        await store.send(.flip(1)) { $0.revealedIndex = 1 }
        XCTAssertEqual(store.state.result?.id, items[1].id)
    }

    @MainActor
    func test_secondFlipIsIgnored() async {
        let items = [snap(1), snap(2), snap(3)]
        let store = TestStore(initialState: CardFlipFeature.State(cutouts: items)) {
            CardFlipFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.start)
        await store.send(.flip(0)) { $0.revealedIndex = 0 }
        await store.send(.flip(2))                          // ignored: already revealed
        XCTAssertEqual(store.state.revealedIndex, 0)
        XCTAssertEqual(store.state.result?.id, items[0].id)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/CardFlipFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — no member `revealedIndex`.

- [ ] **Step 3: Simplify `CardFlipFeature.swift`**

```swift
import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct CardFlipFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot]
        public var cards: [CutoutSnapshot] = []
        public var revealedIndex: Int?
        public var resultInfo: GameResultInfo?
        public init(cutouts: [CutoutSnapshot]) { self.cutouts = cutouts }

        /// The flipped card IS the pick — one flip ends the game.
        public var result: CutoutSnapshot? {
            guard let i = revealedIndex, cards.indices.contains(i) else { return nil }
            return cards[i]
        }
    }

    public enum Action: Equatable {
        case start
        case flip(Int)
        case infoLoaded(GameResultInfo?)
        case playAgain
        case close
    }

    @Dependency(\.random) var random
    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .start:
                state.cards = Array(random.shuffled(state.cutouts).prefix(6))
                state.revealedIndex = nil
                state.resultInfo = nil
                return .none

            case let .flip(index):
                guard
                    state.revealedIndex == nil,
                    state.cards.indices.contains(index)
                else { return .none }
                state.revealedIndex = index
                let picked = state.cards[index]
                return .run { send in
                    let meal = try? await persistence.mealByCutout(picked.id)
                    await send(.infoLoaded(GameResultInfo.from(meal)))
                }

            case let .infoLoaded(info):
                state.resultInfo = info
                return .none

            case .playAgain:
                return .send(.start)

            case .close:
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Update `CardFlipView.swift` surgically**

- Replace `store.revealedIndices.contains(index)` checks with `store.revealedIndex == index`.
- Remove the mismatch-hide `.task(id: store.secondRevealedIndex)` block, the moves-counter text, the matched-pair glow set, and the mismatch shake — plus the "같은 누끼 두 장을 찾아봐" / `card.moves` copy. Use a single hint line: `Text(L10n.text("끌리는 카드 한 장을 골라 뒤집어봐"))` (add the key to all four `.lproj` files if the project's `L10n.text` requires registered keys — check how neighboring literals are handled and match).
- Keep: the perspective 3D flip, card backs, the celebration/ConfettiBurst on result, the reveal `.task(id: store.result?.id)`, `KitschPressStyle`, `OutlineButton`, `PaperBackground`, and the `ResultCard` hand-off (whose `onAgain` should reset any local reveal state).

- [ ] **Step 5: Tests green + build**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/CardFlipFeatureTests -skipMacroValidation 2>&1 | tail -5`
Then: `tuist build FeatureKit`
Expected: `** TEST SUCCEEDED **` (3 tests), `Build Succeeded`.

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Game/CardFlipFeature.swift Sources/FeatureKit/Game/CardFlipView.swift Tests/FeatureKitTests/CardFlipFeatureTests.swift Sources/FoodDiary/Resources
git commit -m "feat(game): card flip picks one card instead of matching pairs

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Roulette — real circular wheel

**Files:**
- Modify: `Sources/FeatureKit/Game/RouletteView.swift` (view-only)

**Interfaces:** reuses `store.reel`, `store.landingIndex`, `store.isSpinning`, `store.result`, `store.resultInfo`, `spin`, `playAgain`, `close`, `appear` — **unchanged**.

- [ ] **Step 1: Build the wheel**

Replace the vertical reel window with a circular wheel. Key pieces:
- A wheel slice of the reel so the winner is always included:
```swift
    private var wheelSlice: [CutoutSnapshot] { Array(store.reel.suffix(8)) }
    private var winnerSliceIndex: Int? {
        guard let landing = store.landingIndex else { return nil }
        let start = max(store.reel.count - wheelSlice.count, 0)
        let idx = landing - start
        return wheelSlice.indices.contains(idx) ? idx : nil
    }
    private var segmentAngle: Double { 360.0 / Double(max(wheelSlice.count, 1)) }
```
- Wedges via a `Shape`: add a small private `Wedge: Shape` (start/end angle → path with `addArc` from the center) — a shape is fine to define in this file.
- The wheel body:
```swift
            ZStack {
                ForEach(Array(wheelSlice.enumerated()), id: \.offset) { index, cutout in
                    let start = Double(index) * segmentAngle - 90
                    Wedge(startAngle: .degrees(start), endAngle: .degrees(start + segmentAngle))
                        .fill([Color.appPink, .appButter, .appBlue, .appLavender][index % 4])
                        .overlay {
                            CutoutImage(fileName: cutout.fileName)
                                .frame(width: 52, height: 52)
                                .offset(y: -74)
                                .rotationEffect(.degrees(start + segmentAngle / 2 + 90))
                        }
                }
                Circle().stroke(Color.appChocolate, lineWidth: 5)
                Circle().fill(Color.appCard).frame(width: 54, height: 54).softShadow()
                    .overlay { KitschSparkle().fill(Color.appButter).frame(width: 24, height: 24) }
            }
            .frame(width: 280, height: 280)
            .rotationEffect(.degrees(wheelRotation))
```
(The per-segment cutout is placed at the wedge's mid-radius by offsetting then counter-rotating so it stays upright relative to the wheel.)
- A fixed pointer above the wheel (outside the rotating stack):
```swift
            .overlay(alignment: .top) {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.appCherry)
                    .offset(y: -12)
            }
```

- [ ] **Step 2: Spin to the winning wedge**

Add `@State private var wheelRotation: Double = 0` and drive it off `landingIndex` (keep the existing `spinDuration` constant; drop `reelOffset`/`reelBlur`/slot constants that no longer apply, and remove now-dead code):
```swift
        .task(id: store.landingIndex) {
            guard let winner = winnerSliceIndex else { return }
            // Land the winning wedge's mid-angle under the top pointer.
            let target = 360.0 * 4 - (segmentAngle * Double(winner) + segmentAngle / 2)
            withAnimation(.timingCurve(0.15, 0.85, 0.2, 1, duration: spinDuration * 0.88)) {
                wheelRotation = target + segmentAngle * 0.18      // slight overshoot
            }
            try? await Task.sleep(for: .seconds(spinDuration * 0.88))
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 16)) {
                wheelRotation = target                            // settle exactly
            }
        }
```
Keep the existing reveal `.task(id: store.result?.id)` (delay keyed to `spinDuration`) so the card appears after the settle; keep `glow`/`winnerPulse` behavior applied to the wheel rim instead of the old frame; reset `wheelRotation = 0` in the `onAgain` closure.

- [ ] **Step 3: Build + roulette tests**

Run: `tuist build FeatureKit`
Then: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/RouletteFeatureTests -skipMacroValidation 2>&1 | tail -4`
Expected: `Build Succeeded`, `** TEST SUCCEEDED **` (reducer untouched → tests pass unchanged).

- [ ] **Step 4: Commit**

```bash
git add Sources/FeatureKit/Game/RouletteView.swift
git commit -m "feat(game): rebuild roulette as a real circular wheel

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Gacha — turnable dial + coin slot

**Files:**
- Modify: `Sources/FeatureKit/Game/GachaView.swift` (view-only)

- [ ] **Step 1: Replace the stick lever with a dial**

Remove the current lever (`Capsule().fill(Color.appCherry).frame(width: 28, height: 118)` + its knob overlay/offset/rotation) and add a dial mounted on the machine face:
```swift
    private var dial: some View {
        ZStack {
            Circle().fill(Color.appCard).frame(width: 62, height: 62).softShadow()
            Circle().stroke(Color.appChocolate, lineWidth: 4).frame(width: 62, height: 62)
            // Turn groove.
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.appChocolate)
                .frame(width: 44, height: 9)
            // Marker dot so the turn is readable.
            Circle().fill(Color.appCherry).frame(width: 8, height: 8).offset(y: -20)
        }
        .rotationEffect(.degrees(dialTurn))
        .animation(.interpolatingSpring(stiffness: 150, damping: 11), value: dialTurn)
    }
```
Add `@State private var dialTurn: Double = 0`, turn it on pull (`dialTurn += 180` in the button action alongside the existing drum spin/shake), and reset to `0` in the same place `capsuleDrop`/`capsuleOpen`/`capsuleSquash` reset.

- [ ] **Step 2: Add a coin slot + mount the dial on the tray face**

In the machine's lower body (the `RoundedRectangle(cornerRadius: 26).fill(Color.appPink)` face), lay out: a coin slot above the dial, then the dial, keeping the existing tray flap art:
```swift
                            // Coin slot.
                            Capsule()
                                .fill(Color.appChocolate.opacity(0.85))
                                .frame(width: 46, height: 10)
                            dial
```
Place these inside that face's existing `VStack` overlay (keep the existing `KitschIcon`/flap elements, adjusting spacing only as needed).

- [ ] **Step 3: Build + commit**

Run: `tuist build FeatureKit` → `Build Succeeded`.
```bash
git add Sources/FeatureKit/Game/GachaView.swift
git commit -m "feat(game): turnable gachapon dial + coin slot

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 4: Final full verification**

Run: `tuist generate --no-open && tuist build FeatureKit`
App: `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' -skipMacroValidation 2>&1 | tail -3`
Full suite: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -skipMacroValidation 2>&1 | tail -6`
Expected: `Build Succeeded`, `BUILD SUCCEEDED`, `** TEST SUCCEEDED **` (the 3 rewritten CardFlip tests + everything else).

---

## Self-Review Notes (against spec)

- **Spec §1 Card Flip simplify** → Task 1 (reducer + view + rewritten tests; pair/mismatch behavior deleted).
- **Spec §2 Roulette wheel** (wedges, top pointer, land winner under pointer via `landingIndex`, overshoot settle, reveal after settle) → Task 2, reducer untouched.
- **Spec §3 Gacha dial + coin slot** → Task 3, view-only, machine art otherwise preserved.
- **Spec §4/§5** → only Task 1 touches tests; full suite verified in Task 3 Step 4.

## Notes for the implementer

- **Read before editing; surgical.** Anything not named must survive.
- Always `-skipMacroValidation`. Booted sim UDID `3B1E5795-617D-4955-8048-0CC8AD03BE95`.
- For the wheel: verify the winner really lands under the pointer by checking the angle formula against `winnerSliceIndex` (the reducer guarantees the winner is `store.reel[landingIndex]`, which is inside the last-8 slice because it's the final element).
- If `L10n.text(...)` requires registered keys, add any new Korean copy to all four `.lproj` files; otherwise match how neighboring literals are handled.
- Games need real cutouts + a device for full feel; build/tests are the gate here.
