# Game Quality Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the four decider games feel real — the reel/capsule lands on the ACTUAL winner, contenders show real food info, results are rich (place/date/memo/rating), and the hub separates solo vs group play.

**Architecture:** One shared `GameResultInfo` replaces the thin `resultPlace` across all four game reducers (+ `ResultCard`). `RouletteFeature` gains a real `landingIndex` so the view can stop on the winning slot. Gacha/World Cup/Card Flip get view-level payoff animations (+ a World Cup info lookup). `GameHubView` gets two labeled sections and a consistent group card.

**Tech Stack:** SwiftUI, TCA 1.26, existing kitsch/pastel DesignSystem, iOS 18, Swift 6.

## Global Constraints

- **These game files were hand-evolved — READ each current file fully before editing and edit SURGICALLY.** Preserve existing visuals (PaperBackground, KitschIcon, WashiTape, KitschPressStyle, ConfettiBurst, L10n, sensoryFeedback) and existing behaviors not named in a task.
- Do NOT touch Collection/Capture/Map/Achievements/Recap/Profile/streak/widget code.
- Randomness only via `RandomClient` — the reducer picks the winner; views only animate toward it.
- Korean UI + `L10n`; English comments; light mode.
- Build `tuist build FeatureKit`; tests `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:<Bundle>/<Class> -skipMacroValidation`; app build via `FoodDiary` scheme `-skipMacroValidation`. Regenerate after adding files. Never `tuist install`; never edit `Project.swift`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Task 1: `GameResultInfo` + rich `ResultCard` (all four games)

**Files:**
- Create: `Sources/FeatureKit/Game/GameResultInfo.swift`
- Modify: `Sources/FeatureKit/Game/GachaFeature.swift`, `RouletteFeature.swift`, `CardFlipFeature.swift`, `WorldCupFeature.swift`
- Modify: `Sources/FeatureKit/Game/ResultCard.swift`
- Modify: `Sources/FeatureKit/Game/GachaView.swift`, `RouletteView.swift`, `CardFlipView.swift`, `WorldCupView.swift` (call-site rename only)
- Modify: `Tests/FeatureKitTests/GachaFeatureTests.swift`

**Interfaces:**
- Produces: `public struct GameResultInfo: Equatable, Sendable { let placeName: String; let dateText: String; let memo: String; let rating: Int? ; init(...) }` + `static func from(_ meal: MealSnapshot?) -> GameResultInfo?`.
- Each game reducer: `resultPlace: String?` → `resultInfo: GameResultInfo?` (WorldCup: `championPlace` → `championInfo`), and `placeLoaded(String?)` → `infoLoaded(GameResultInfo?)`.
- `ResultCard(cutout:info:onAgain:onClose:)`.

- [ ] **Step 1: Write `GameResultInfo.swift`**

```swift
import Foundation
import Models

public struct GameResultInfo: Equatable, Sendable {
    public let placeName: String
    public let dateText: String
    public let memo: String
    public let rating: Int?

    public init(placeName: String, dateText: String, memo: String, rating: Int?) {
        self.placeName = placeName
        self.dateText = dateText
        self.memo = memo
        self.rating = rating
    }

    /// Builds the richer result payload from a meal snapshot (nil when unknown).
    public static func from(_ meal: MealSnapshot?) -> GameResultInfo? {
        guard let meal else { return nil }
        return GameResultInfo(
            placeName: meal.place?.name ?? "",
            dateText: meal.eatenAt.formatted(.dateTime.month().day().weekday()),
            memo: meal.memo,
            rating: meal.rating
        )
    }
}
```

- [ ] **Step 2: Update the four reducers (surgical rename + payload)**

In each of `GachaFeature`, `RouletteFeature`, `CardFlipFeature`:
- State: rename `resultPlace: String?` → `resultInfo: GameResultInfo?` (update every assignment, including the resets in `playAgain`/`start`/`spin`/`pullLever`).
- Action: rename `case placeLoaded(String?)` → `case infoLoaded(GameResultInfo?)`.
- In the reveal effect, replace the place-name extraction with the meal→info mapping, e.g.:
```swift
                return .run { send in
                    let meal = try? await persistence.mealByCutout(pick.id)
                    await send(.infoLoaded(GameResultInfo.from(meal)))
                }
```
(keep the surrounding structure/actions as they currently are), and
```swift
            case let .infoLoaded(info):
                state.resultInfo = info
                return .none
```
In `WorldCupFeature`: same, with `championPlace` → `championInfo` and its `.run` effect mapping through `GameResultInfo.from(...)`.

- [ ] **Step 3: Make `ResultCard` rich**

Change its signature to `let info: GameResultInfo?` and render, keeping the existing ConfettiBurst / StickerTile / WashiTape / buttons:
- title line: `Text(info?.placeName.isEmpty == false ? info!.placeName : L10n.text("오늘의 한 끼"))` (existing `.appDisplay` styling),
- under it a date chip when `info?.dateText` is non-empty: `PastelChip(dateText, glyph: "📅", tone: .pink)` (or the codebase's current chip component),
- the memo in quotes (`.appBody`, `.appInk`) when non-empty,
- a star row when `rating != nil` (reuse `StarRating(rating:)` if present, else `Text(String(repeating: "★", count: rating))` in `.appButterInk`).

- [ ] **Step 4: Update the four views' call sites**

Replace `place: store.resultPlace` → `info: store.resultInfo` (WorldCup: `place: store.championPlace` → `info: store.championInfo`). No other view change in this task.

- [ ] **Step 5: Update `GachaFeatureTests.swift`**

The existing test overrides `persistence.mealByCutout` and receives `\.placeLoaded` asserting `resultPlace == "라멘집"`. Update to receive `\.infoLoaded` and assert `store.state.resultInfo?.placeName == "라멘집"` (keep the same stubbed meal + the `pullLever` assertions unchanged).

- [ ] **Step 6: Build + run the game tests**

Run: `tuist generate --no-open && tuist build FeatureKit`
Then: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/GachaFeatureTests -only-testing:FeatureKitTests/RouletteFeatureTests -only-testing:FeatureKitTests/CardFlipFeatureTests -only-testing:FeatureKitTests/WorldCupFeatureTests -skipMacroValidation 2>&1 | tail -6`
Expected: `Build Succeeded` and `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add Sources/FeatureKit/Game Tests/FeatureKitTests/GachaFeatureTests.swift
git commit -m "feat(game): rich GameResultInfo (place/date/memo/rating) in results

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Roulette stops on the actual winner

**Files:**
- Modify: `Sources/FeatureKit/Game/RouletteFeature.swift`
- Modify: `Sources/FeatureKit/Game/RouletteView.swift`
- Modify: `Tests/FeatureKitTests/RouletteFeatureTests.swift`

**Interfaces:**
- `RouletteFeature.State` gains `public var landingIndex: Int?`. On `.spin`, the reel is rebuilt so the winner is the last slot and `landingIndex = reel.count - 1`.

- [ ] **Step 1: Add the failing test**

Append to `Tests/FeatureKitTests/RouletteFeatureTests.swift`:
```swift
    @MainActor
    func test_spin_placesWinnerAtLandingIndex() async {
        let items = [snap(1), snap(2), snap(3)]
        let picked = items[2]
        let store = TestStore(initialState: RouletteFeature.State(cutouts: items)) {
            RouletteFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.random.pick = { _ in picked }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.spin)
        XCTAssertEqual(store.state.result?.id, picked.id)
        XCTAssertEqual(store.state.reel.last?.id, picked.id)
        XCTAssertEqual(store.state.landingIndex, store.state.reel.count - 1)
    }
```
(Reuse the file's existing `snap(_:)` helper; if it's named differently, use the existing one.)

- [ ] **Step 2: Run to verify failure**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/RouletteFeatureTests/test_spin_placesWinnerAtLandingIndex -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — no member `landingIndex`.

- [ ] **Step 3: Edit `RouletteFeature.swift`**

- Add to `State`: `public var landingIndex: Int?` (and reset it to `nil` in `playAgain`).
- In the `.spin` case, after picking the winner, rebuild the reel so the winner is the final slot:
```swift
            case .spin:
                guard let pick = random.pick(state.cutouts) else { return .none }
                state.isSpinning = true
                state.result = pick
                state.resultInfo = nil
                // Rebuild the reel so the picked cutout IS the slot the reel stops on.
                var reel = (0..<3).flatMap { _ in random.shuffled(state.cutouts) }
                reel.append(pick)
                state.reel = reel
                state.landingIndex = reel.count - 1
                return .run { send in
                    let meal = try? await persistence.mealByCutout(pick.id)
                    await send(.infoLoaded(GameResultInfo.from(meal)))
                }
```
(Keep `.appear`'s initial reel build as-is for the idle visual.)

- [ ] **Step 4: Edit `RouletteView.swift`** — pointer + land on the winner

- Extract the slot height into a constant, e.g. `private let slotHeight: CGFloat = 120` and use it for each reel row's `.frame(height:)` + padding so the math matches (rows currently `height: 112` + `.vertical, 4` padding = 120).
- Add a **center pointer** overlay on the reel window: a `Capsule().fill(Color.appCherry)` bar (or two side arrows) marking the winning row, e.g.
```swift
                    .overlay(alignment: .center) {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appCherry, lineWidth: 4)
                            .frame(height: slotHeight)
                            .overlay(alignment: .leading) {
                                Triangle placeholder — use Image(systemName: "arrowtriangle.right.fill")
                                    .foregroundStyle(Color.appCherry).offset(x: -14)
                            }
                            .overlay(alignment: .trailing) {
                                Image(systemName: "arrowtriangle.left.fill")
                                    .foregroundStyle(Color.appCherry).offset(x: 14)
                            }
                            .allowsHitTesting(false)
                    }
```
(Use real SwiftUI — no placeholder text; keep the existing sparkle overlays.)
- In the spin button action, animate to the winner's slot instead of a fixed offset. Because the reducer sets `landingIndex` when `.spin` is handled, drive the animation off a `.task(id: store.landingIndex)`:
```swift
        .task(id: store.landingIndex) {
            guard let index = store.landingIndex else { return }
            withAnimation(.timingCurve(0.12, 0.8, 0.2, 1, duration: 1.6)) {
                // Center the winning slot in the window.
                reelOffset = -CGFloat(index) * slotHeight + (windowHeight - slotHeight) / 2
            }
        }
```
with `private let windowHeight: CGFloat = 270` (the current reel window frame height). Remove the old fixed-offset animation from the button (keep `glow`, haptics, and the disabled state).
- Keep the existing 1.5 s reveal `.task(id: store.result?.id)` (it now reveals AFTER the reel has visibly landed on that cutout).

- [ ] **Step 5: Run the test + build**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/RouletteFeatureTests -skipMacroValidation 2>&1 | tail -5`
Then: `tuist build FeatureKit`
Expected: `** TEST SUCCEEDED **`, `Build Succeeded`.

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Game/RouletteFeature.swift Sources/FeatureKit/Game/RouletteView.swift Tests/FeatureKitTests/RouletteFeatureTests.swift
git commit -m "fix(game): roulette stops on the actual winning slot + pointer

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Gacha dispenses the chosen capsule

**Files:**
- Modify: `Sources/FeatureKit/Game/GachaView.swift`

**Interfaces:** view-only (no reducer change). Uses `store.result` (already set before the reveal) to animate the winning capsule.

- [ ] **Step 1: Add dispense state + animation**

In `GachaView`, add:
```swift
    @State private var capsuleDrop: CGFloat = -140   // y offset of the dispensed capsule
    @State private var capsuleOpen = false
```
Add a dispensed-capsule view that appears once `store.result != nil` and `revealResult == false` (i.e. during the existing pre-reveal window), layered over the tray:
```swift
    @ViewBuilder
    private func dispensedCapsule(_ cutout: CutoutSnapshot) -> some View {
        ZStack {
            // Two halves that part when the capsule opens.
            Circle()
                .fill(Color.appPink)
                .frame(width: 96, height: 96)
                .mask(Rectangle().frame(height: 48).offset(y: -24))
                .offset(y: capsuleOpen ? -30 : 0)
            Circle()
                .fill(Color.appButter)
                .frame(width: 96, height: 96)
                .mask(Rectangle().frame(height: 48).offset(y: 24))
                .offset(y: capsuleOpen ? 30 : 0)
            CutoutImage(fileName: cutout.fileName)
                .frame(width: 74, height: 74)
                .scaleEffect(capsuleOpen ? 1.15 : 0.6)
                .opacity(capsuleOpen ? 1 : 0)
        }
        .offset(y: capsuleDrop)
        .overlay(alignment: .center) {
            if capsuleOpen { KitschSparkle().fill(Color.appButter).frame(width: 26, height: 26).offset(y: -46) }
        }
    }
```
Place it in the machine ZStack (e.g. `.overlay(alignment: .bottom) { if let r = store.result, !revealResult { dispensedCapsule(r) } }` on `capsuleMachine`), positioned over the tray.

- [ ] **Step 2: Sequence the animation and extend the reveal window**

Replace the existing `.task(id: store.result?.id)` reveal block with a sequenced one:
```swift
        .task(id: store.result?.id) {
            guard store.result != nil else {
                revealResult = false
                capsuleDrop = -140
                capsuleOpen = false
                return
            }
            // 1) capsule falls into the tray
            withAnimation(.interpolatingSpring(stiffness: 170, damping: 12)) { capsuleDrop = 26 }
            try? await Task.sleep(for: .milliseconds(520))
            // 2) it splits open, revealing the cutout
            withAnimation(.spring(response: 0.42, dampingFraction: 0.6)) { capsuleOpen = true }
            try? await Task.sleep(for: .milliseconds(700))
            // 3) hand off to the result card
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { revealResult = true }
        }
```
Also reset `capsuleDrop`/`capsuleOpen` in the `playAgain` path (the `onAgain` closure passed to `ResultCard`). Keep the drum-spin `drumTurns` animation and the lever tilt as-is; keep haptics.

- [ ] **Step 3: Build to verify**

Run: `tuist generate --no-open && tuist build FeatureKit`
Expected: `Build Succeeded`.

- [ ] **Step 4: Commit**

```bash
git add Sources/FeatureKit/Game/GachaView.swift
git commit -m "feat(game): gacha dispenses and opens the winning capsule

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: World Cup contender info + round banner; Card Flip celebration

**Files:**
- Modify: `Sources/FeatureKit/Game/WorldCupFeature.swift`
- Modify: `Sources/FeatureKit/Game/WorldCupView.swift`
- Modify: `Sources/FeatureKit/Game/CardFlipView.swift`
- Modify: `Tests/FeatureKitTests/WorldCupFeatureTests.swift`

**Interfaces:**
- `WorldCupFeature.State` gains `public var info: [UUID: GameResultInfo] = [:]`; `Action` gains `case infoTableLoaded([UUID: GameResultInfo])`; `.start` also loads it from `persistence.allMeals()`.

- [ ] **Step 1: Add the failing test**

Append to `Tests/FeatureKitTests/WorldCupFeatureTests.swift`:
```swift
    @MainActor
    func test_start_loadsContenderInfo() async {
        let items = [snap(1), snap(2)]
        let meal = MealSnapshot(
            id: UUID(), eatenAt: Date(),
            place: PlaceInfo(id: "p", name: "라멘집", address: ""),
            memo: "존맛", rating: 5, cutouts: items
        )
        let store = TestStore(initialState: WorldCupFeature.State(cutouts: items)) {
            WorldCupFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.persistence.allMeals = { [meal] }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.start)
        await store.receive(\.infoTableLoaded)
        XCTAssertEqual(store.state.info[items[0].id]?.placeName, "라멘집")
        XCTAssertEqual(store.state.info[items[0].id]?.memo, "존맛")
    }
```
(Use the file's existing `snap(_:)` helper and add `import Models` if the test file lacks it.)

- [ ] **Step 2: Run to verify failure**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/WorldCupFeatureTests/test_start_loadsContenderInfo -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — no member `info`/`infoTableLoaded`.

- [ ] **Step 3: Edit `WorldCupFeature.swift`**

- `State`: add `public var info: [UUID: GameResultInfo] = [:]`.
- `Action`: add `case infoTableLoaded([UUID: GameResultInfo])`.
- In `.start`, return an effect that builds the table (keep the existing bracket setup mutations):
```swift
                return .run { send in
                    let meals = (try? await persistence.allMeals()) ?? []
                    var table: [UUID: GameResultInfo] = [:]
                    for meal in meals {
                        guard let info = GameResultInfo.from(meal) else { continue }
                        for cutout in meal.cutouts { table[cutout.id] = info }
                    }
                    await send(.infoTableLoaded(table))
                }
```
- Add:
```swift
            case let .infoTableLoaded(table):
                state.info = table
                return .none
```

- [ ] **Step 4: Edit `WorldCupView.swift`** — real labels + round banner

- In `contender(_:index:)`, replace the `Text(index == 0 ? "LEFT PICK" : "RIGHT PICK")` label with the real info:
```swift
                let info = store.info[cutout.id]
                VStack(spacing: 2) {
                    Text(info?.placeName.isEmpty == false ? info!.placeName : L10n.text("이 메뉴"))
                        .font(.appCaption).foregroundStyle(.appChocolate)
                        .lineLimit(1)
                    if let memo = info?.memo, !memo.isEmpty {
                        Text(memo).font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.appMuted).lineLimit(1)
                    }
                }
```
(keep the surrounding StickerTile/card chrome, scaleEffect, rotation, KitschPressStyle).
- Add a brief round-transition banner: a `@State private var roundBanner: String?`, set it in a `.task(id: store.currentRound.count)` when the round changes (e.g. `roundBanner = store.roundName`), show it as an overlay capsule (`.appCherry` background, `.appCard` text) for ~0.9 s, then clear.

- [ ] **Step 5: Edit `CardFlipView.swift`** — match + win celebration

- Add `@State private var matchPulse = 0` and a `"매치!"` badge overlay shown briefly when a pair matches: drive it from `.task(id: store.moves)` / the existing matched state (use whatever the reducer exposes for a successful pair — e.g. when `revealedIndices` grows without a pending mismatch). Keep it simple: when `store.result != nil` show a `ConfettiBurst()` behind the grid before the result card appears (reuse the existing component), plus scale the matched tiles slightly.
- Do not change the reducer.

- [ ] **Step 6: Run tests + build**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/WorldCupFeatureTests -only-testing:FeatureKitTests/CardFlipFeatureTests -skipMacroValidation 2>&1 | tail -5`
Then: `tuist build FeatureKit`
Expected: `** TEST SUCCEEDED **`, `Build Succeeded`.

- [ ] **Step 7: Commit**

```bash
git add Sources/FeatureKit/Game/WorldCupFeature.swift Sources/FeatureKit/Game/WorldCupView.swift Sources/FeatureKit/Game/CardFlipView.swift Tests/FeatureKitTests/WorldCupFeatureTests.swift
git commit -m "feat(game): world cup contender info + round banner, card flip celebration

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Hub sections + consistent group card + full verification

**Files:**
- Modify: `Sources/FeatureKit/Game/GameHubView.swift`

**Interfaces:** view-only; keeps `gameTapped`/`groupTapped` and both `fullScreenCover`s.

- [ ] **Step 1: Split into two labeled sections**

Inside the existing `ScreenScaffold`, wrap content so it reads:
1. the existing intro `SoftCard` (unchanged),
2. a section header `"혼자 결정"` + caption `"내 누끼로 바로 정하기"`,
3. the existing 4-card `LazyVGrid` (unchanged),
4. a section header `"같이 결정"` + caption `"친구들과 같은 결과를 함께"`,
5. the group card (restyled, below).

Section header helper:
```swift
    private func sectionHeader(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.text(title)).font(.appSection).foregroundStyle(.appInk)
            Text(L10n.text(caption)).font(.appCaption).foregroundStyle(.appMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
```

- [ ] **Step 2: Restyle the group card to match the game cards**

Replace the current group `Button { ... } label: { SoftCard { VStack(spacing: 8) { Text("🎉") ... } } }` with the same visual language as `GameKind` cards:
```swift
            Button { store.send(.groupTapped) } label: {
                SoftCard {
                    VStack(alignment: .leading, spacing: 10) {
                        KitschIcon("person.2.fill", tint: .appChocolate, background: .appLavender, size: 56)
                        Text(L10n.text("함께 정하기")).font(.appTitle).foregroundStyle(.appInk)
                        Text(L10n.text("친구를 초대해 다 같이 결정"))
                            .font(.appCaption).foregroundStyle(.appMuted)
                            .multilineTextAlignment(.leading)
                        Label(L10n.text("게임센터"), systemImage: "gamecontroller.fill")
                            .font(.appCaption).foregroundStyle(.appBlueInk)
                    }
                    .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
                }
                .rotationEffect(.degrees(1))
            }
            .buttonStyle(KitschPressStyle())
```

- [ ] **Step 3: Build module + app + FULL suite**

Run: `tuist generate --no-open && tuist build FeatureKit`
App: `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' -skipMacroValidation 2>&1 | tail -3`
Full suite: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -skipMacroValidation 2>&1 | tail -6`
Expected: `Build Succeeded`, `BUILD SUCCEEDED`, `** TEST SUCCEEDED **` (all existing tests + the new roulette/worldcup ones).

- [ ] **Step 4: Commit**

```bash
git add Sources/FeatureKit/Game/GameHubView.swift
git commit -m "feat(game): split hub into solo/group sections with consistent cards

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review Notes (against spec)

- **Spec §3 GameResultInfo + rich ResultCard across 4 games** → Task 1 (+ GachaFeatureTests updated).
- **Spec §4 roulette lands on winner + pointer** → Task 2 (new reducer test asserts `reel.last == winner` and `landingIndex`).
- **Spec §5 gacha dispense/open** → Task 3 (view-only, sequenced animation).
- **Spec §6 world cup contender info + round banner; card flip celebration** → Task 4 (+ new WorldCup info test).
- **Spec §7 hub sections + consistent group card** → Task 5.
- **Spec §8 testing** → per-task reducer tests + full suite in Task 5; view feel device-verified.
- **Type consistency:** `resultInfo`/`championInfo`/`infoLoaded`/`infoTableLoaded`/`landingIndex`/`GameResultInfo.from` used consistently across reducers, views, and tests.

## Notes for the implementer

- **Read each file before editing; edit surgically.** These views are hand-tuned; keep every existing visual/behavior not named in the task.
- Always `-skipMacroValidation`. Booted sim UDID `3B1E5795-617D-4955-8048-0CC8AD03BE95` (else `xcrun simctl list devices booted`).
- If a component name differs (`PastelChip`, `StarRating`, `KitschSparkle`, `ConfettiBurst`, `OutlineButton`), use the codebase's current spelling — do not invent components.
- Games need real cutouts to play; the simulator can't create them (Vision), so animations are build-verified here and device-verified by the user.
