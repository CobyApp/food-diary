# Game Polish v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the game hub (no banner, tighter cards, lock/progress affordance, full-width group row, staggered entrance) and polish all four games' design/animation meticulously.

**Architecture:** 100% view-layer. No reducer/state/action changes anywhere, so the existing test suite is the untouched regression net. Each task edits one or two hand-evolved SwiftUI files surgically.

**Tech Stack:** SwiftUI, existing kitsch/pastel DesignSystem, iOS 18, Swift 6.

## Global Constraints

- **NO reducer/state/action changes.** If a polish idea seems to need one, drop that idea and note it — do not touch reducers or tests.
- **Read each file fully before editing; edit SURGICALLY.** Preserve every existing component and behavior not named in the task (`SoftCard`, `KitschIcon`, `KitschPressStyle`, `KitschSparkle`, `ConfettiBurst`, `WashiTape`, `PaperBackground`, `KitschLoadingView`, `OutlineButton`, `PillButton`, `L10n`, haptics). **Do not invent components.**
- Korean UI + `L10n`; light mode.
- Build `tuist build FeatureKit`; app build `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' -skipMacroValidation`. Full suite at the end. Regenerate with `tuist generate --no-open` when files are added. Never `tuist install`; never edit `Project.swift`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Task 1: Hub rework

**Files:**
- Modify: `Sources/FeatureKit/Game/GameHubView.swift`

**Interfaces:** view-only. Uses existing `store.cutouts`, `GameKind` (`title`/`subtitle`/`symbol`/`minimum`), `gameTapped`, `groupTapped`, both `fullScreenCover`s, `.task`, sensory feedback — all preserved.

- [ ] **Step 1: Delete the intro banner**

Remove the entire leading `SoftCard { HStack { KitschIcon("wand.and.stars" …) … } }` block (the "결정은 게임에게 맡겨" card). The screen now starts with the status strip.

- [ ] **Step 2: Add a compact status strip** (replaces the banner's role)

Add above the first section header:
```swift
    private var statusStrip: some View {
        let locked = GameKind.allCases.filter { store.cutouts.count < $0.minimum }
        let needed = locked.map(\.minimum).max().map { $0 - store.cutouts.count } ?? 0
        return HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "square.grid.2x2.fill").foregroundStyle(Color.appBlueInk)
                Text(L10n.format("game.myCutouts", store.cutouts.count))
                    .font(.appCaption).foregroundStyle(.appInk)
            }
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Color.appCard, in: Capsule())
            .softShadow()

            if needed > 0 {
                Text(L10n.format("game.needMore", needed))
                    .font(.appCaption).foregroundStyle(.appMuted)
            }
            Spacer()
        }
    }
```
Add the two keys to **all four** `Localizable.strings` files (`ko`, `en`, `ja`, `zh-Hans`), following the existing formatting style used by e.g. `game.minimum`:
- `"game.myCutouts" = "내 누끼 %d개";` (en: `"%d stickers"`, ja: `"ヌッキ %d個"`, zh-Hans: `"我的贴纸 %d 张"`)
- `"game.needMore" = "%d개만 더 모으면 다 열려요";` (en: `"%d more to unlock all"`, ja: `"あと%d個で全部開きます"`, zh-Hans: `"再攒 %d 张就全部解锁"`)
(If the project's `L10n.format` keys live elsewhere, match that mechanism.)

- [ ] **Step 3: Tighten the solo cards + badge-style lock**

In the solo `LazyVGrid`, replace the card label content with a tighter layout (keep the `Button`, `store.send(.gameTapped(kind))`, `KitschPressStyle`, per-index rotation, and `.disabled(!enabled)`):
```swift
                        SoftCard {
                            VStack(alignment: .leading, spacing: 8) {
                                KitschIcon(
                                    kind.symbol,
                                    tint: .appChocolate,
                                    background: [.appPink, .appButter, .appBlue, .appLavender][index],
                                    size: 48
                                )
                                .saturation(enabled ? 1 : 0.35)
                                Text(kind.title)
                                    .font(.appSection).foregroundStyle(.appInk)
                                    .lineLimit(1).minimumScaleFactor(0.85)
                                Text(kind.subtitle)
                                    .font(.appCaption).foregroundStyle(.appMuted)
                                    .lineLimit(2).multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
                        }
                        .overlay(alignment: .topTrailing) {
                            if !enabled {
                                HStack(spacing: 3) {
                                    Image(systemName: "lock.fill")
                                    Text("\(kind.minimum)")
                                }
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appPinkInk)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(Color.appPink.opacity(0.9), in: Capsule())
                                .padding(9)
                            }
                        }
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1 : 1))
                        .opacity(enabled ? 1 : 0.82)
```
Also change the grid to `[GridItem(.adaptive(minimum: 150), spacing: 12)]` with `spacing: 12`.

- [ ] **Step 4: Make the group entry a full-width row**

Replace the group `Button`'s label with a horizontal row (keep `groupTapped` + `KitschPressStyle`):
```swift
                SoftCard {
                    HStack(spacing: 14) {
                        KitschIcon("person.2.fill", tint: .appChocolate, background: .appLavender, size: 50)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.text("함께 정하기"))
                                .font(.appSection).foregroundStyle(.appInk)
                            Text(L10n.text("친구를 초대해 다 같이 결정"))
                                .font(.appCaption).foregroundStyle(.appMuted)
                            Label(L10n.text("게임센터"), systemImage: "gamecontroller.fill")
                                .font(.appCaption).foregroundStyle(.appBlueInk)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.appSection).foregroundStyle(.appMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
```
(Drop the previous `minHeight: 170` / rotation on this card.)

- [ ] **Step 5: Staggered entrance**

Add `@State private var appeared = false`, set it in the existing `.task` (`withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }` after the existing `store.send(.onAppear)`), and apply to each solo card and the group row:
```swift
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.85)
                                .delay(Double(index) * 0.06),
                            value: appeared
                        )
```
(For the group row use a fixed delay of `0.28`.)

- [ ] **Step 6: Build + screenshot check**

Run: `tuist generate --no-open && tuist build FeatureKit`
Then app: `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' -skipMacroValidation 2>&1 | tail -3`
Expected: `Build Succeeded`, `BUILD SUCCEEDED`. (The controller screenshots the hub.)

- [ ] **Step 7: Commit**

```bash
git add Sources/FeatureKit/Game/GameHubView.swift Sources/FoodDiary/Resources
git commit -m "feat(game): rework hub — drop banner, tighter cards, lock badge, group row

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Gacha animation polish

**Files:**
- Modify: `Sources/FeatureKit/Game/GachaView.swift`

**Interfaces:** view-only; uses the existing `drumTurns`, `capsuleDrop`, `capsuleOpen`, `store.isSpinning`, `store.result`, `revealResult`.

- [ ] **Step 1: Drum shake + glass shine**

- Add `@State private var drumShake: CGFloat = 0`. On lever pull (inside the existing button action, alongside the `drumTurns` animation) do a quick shake:
```swift
                        withAnimation(.easeInOut(duration: 0.09).repeatCount(4, autoreverses: true)) {
                            drumShake = 5
                        }
                        withAnimation(.easeOut(duration: 0.5).delay(0.36)) { drumShake = 0 }
```
and apply `.offset(x: drumShake)` to the drum circle stack.
- Add a glass shine on the drum: overlay on the drum `ZStack`
```swift
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.55), Color.white.opacity(0.02)],
                                startPoint: .topLeading, endPoint: .center
                            )
                        )
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }
```

- [ ] **Step 2: Lever spring-back + capsule squash landing**

- Lever: keep the existing tilt while `isSpinning`, but make the return springy by wrapping the rotation in `.animation(.interpolatingSpring(stiffness: 220, damping: 9), value: store.isSpinning)`.
- Capsule landing squash: add `@State private var capsuleSquash: CGFloat = 1`, and in the existing dispense sequence, right after the fall completes, add
```swift
            withAnimation(.easeOut(duration: 0.09)) { capsuleSquash = 0.86 }
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.interpolatingSpring(stiffness: 320, damping: 12)) { capsuleSquash = 1 }
```
and apply `.scaleEffect(x: 1 / capsuleSquash, y: capsuleSquash, anchor: .bottom)` to the dispensed capsule. Reset it to `1` wherever `capsuleDrop`/`capsuleOpen` are reset.

- [ ] **Step 3: Sparkle burst on open**

When `capsuleOpen` becomes true, show 5 `KitschSparkle()` shapes radiating from the capsule (fixed angles, scale+opacity in). Keep it simple and deterministic (no `Math.random`), e.g. a `ForEach(0..<5)` with `.offset` on `cos/sin(Double(i) / 5 * 2 * .pi)` radius 44, `.opacity(capsuleOpen ? 1 : 0)`, `.scaleEffect(capsuleOpen ? 1 : 0.2)`, animated with a small per-index delay.

- [ ] **Step 4: Build + commit**

Run: `tuist build FeatureKit` → `Build Succeeded`.
```bash
git add Sources/FeatureKit/Game/GachaView.swift
git commit -m "feat(game): gacha drum shake, glass shine, capsule squash + sparkles

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Roulette animation polish

**Files:**
- Modify: `Sources/FeatureKit/Game/RouletteView.swift`

**Interfaces:** view-only; uses existing `slotHeight`, `windowHeight`, `spinDuration`, `reelOffset`, `glow`, `store.landingIndex`, `store.reel`, `store.isSpinning`.

- [ ] **Step 1: Slot separators**

Between reel rows, add a thin dashed divider so motion is readable:
```swift
                                Rectangle()
                                    .fill(Color.appCard.opacity(0.55))
                                    .frame(height: 1.5)
                                    .padding(.horizontal, 26)
```
(inside the reel `VStack`, after each row — keep the row frame/padding math so `slotHeight` stays exact: put the divider inside the existing per-row vertical padding, not adding height.)

- [ ] **Step 2: Motion blur that ramps down**

Add `@State private var reelBlur: CGFloat = 0`; apply `.blur(radius: reelBlur)` to the reel `VStack`. In the existing `.task(id: store.landingIndex)`, set it before/after the spin animation:
```swift
            withAnimation(.easeOut(duration: 0.18)) { reelBlur = 3.5 }
            withAnimation(.easeIn(duration: spinDuration * 0.75).delay(spinDuration * 0.25)) { reelBlur = 0 }
```

- [ ] **Step 3: Overshoot then settle**

Replace the single spin animation with an overshoot pair inside the same `.task(id: store.landingIndex)`:
```swift
            let target = -CGFloat(index) * slotHeight + (windowHeight - slotHeight) / 2
            withAnimation(.timingCurve(0.12, 0.8, 0.2, 1, duration: spinDuration * 0.86)) {
                reelOffset = target - slotHeight * 0.22      // slightly past the slot
            }
            try? await Task.sleep(for: .seconds(spinDuration * 0.86))
            withAnimation(.interpolatingSpring(stiffness: 210, damping: 15)) {
                reelOffset = target                          // settle onto it
            }
```
(Keep the reveal delay keyed off `spinDuration` so the card still appears after the settle.)

- [ ] **Step 4: Winner glow pulse**

Add `@State private var winnerPulse = false`; after the settle in the same task:
```swift
            withAnimation(.easeInOut(duration: 0.32).repeatCount(3, autoreverses: true)) { winnerPulse = true }
```
and give the existing center pointer/frame overlay a pulse, e.g. `.shadow(color: Color.appButter.opacity(winnerPulse ? 0.9 : 0), radius: winnerPulse ? 14 : 0)` plus `.scaleEffect(winnerPulse ? 1.02 : 1)`. Reset `winnerPulse = false` on `playAgain` (the existing `onAgain` closure).

- [ ] **Step 5: Build + commit**

Run: `tuist build FeatureKit` → `Build Succeeded`.
```bash
git add Sources/FeatureKit/Game/RouletteView.swift
git commit -m "feat(game): roulette separators, motion blur, overshoot settle, winner pulse

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: World Cup + Card Flip animation polish

**Files:**
- Modify: `Sources/FeatureKit/Game/WorldCupView.swift`
- Modify: `Sources/FeatureKit/Game/CardFlipView.swift`

**Interfaces:** view-only. World Cup uses `store.currentPair`, `store.pairIndex`, `store.currentRound`, `store.roundName`, `store.info`, `pick`. Card Flip uses `store.cards`, `store.revealedIndices`, `store.firstRevealedIndex`, `store.secondRevealedIndex`, `store.moves`, `store.result`.

- [ ] **Step 1: World Cup — per-card pick transition**

Replace the whole-view `.id(store.pairIndex)` + view-level transition with per-card motion so the winner reads as "chosen":
- Add `@State private var pickedID: UUID?` (reuse the existing `selectedID` if present — do not duplicate).
- On tap, set it, then let the pair change animate: give each contender
```swift
            .scaleEffect(selectedID == cutout.id ? 1.1 : (selectedID == nil ? 1 : 0.9))
            .opacity(selectedID == nil || selectedID == cutout.id ? 1 : 0.25)
            .offset(x: selectedID == nil || selectedID == cutout.id ? 0 : (index == 0 ? -40 : 40))
            .animation(.spring(response: 0.42, dampingFraction: 0.8), value: selectedID)
```
- Clear `selectedID` when the pair advances: `.task(id: store.pairIndex) { selectedID = nil }`.
- Keep the transition on the pair container but base its `.id` on `store.pairIndex` only if it still animates cleanly with the above; otherwise drop the container transition in favor of the per-card motion.

- [ ] **Step 2: World Cup — bracket progress dots + VS pop**

- Under the round name, replace/augment the existing `ProgressView` with dots:
```swift
                        HStack(spacing: 6) {
                            let matches = max(store.currentRound.count / 2, 1)
                            ForEach(0..<matches, id: \.self) { i in
                                Circle()
                                    .fill(i < store.pairIndex / 2 ? Color.appCherry : Color.appCherry.opacity(0.25))
                                    .frame(width: 7, height: 7)
                            }
                        }
```
(Keep the round name/label chrome; the `ProgressView` may be removed in favor of dots.)
- VS badge pop: `.scaleEffect(vsPop ? 1.12 : 1)` with `@State private var vsPop = false`, toggled briefly in `.task(id: store.pairIndex)`.

- [ ] **Step 3: Card Flip — perspective flip + match/mismatch feedback**

- Give the flip real depth: on both the existing `rotation3DEffect` calls add `perspective: 0.6`.
- Matched pair glow: add `@State private var matchedGlow: Set<Int> = []`; in the existing `.task(id: store.secondRevealedIndex)` — which already handles the mismatch hide — when the two revealed cards are a match (i.e. `store.result != nil` or the reducer keeps them revealed), insert those indices into `matchedGlow` and apply to the tile:
```swift
                                .overlay {
                                    if matchedGlow.contains(index) {
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.appButter, lineWidth: 4)
                                            .shadow(color: Color.appButter.opacity(0.8), radius: 8)
                                    }
                                }
                                .scaleEffect(matchedGlow.contains(index) ? 1.05 : 1)
```
- Mismatch shake: add `@State private var shake: CGFloat = 0`; when the mismatch hide runs, animate `shake` (e.g. `.easeInOut(duration: 0.07).repeatCount(4, autoreverses: true)` to `6`, then back to `0`) and apply `.offset(x: store.secondRevealedIndex == index || store.firstRevealedIndex == index ? shake : 0)`.
- If any of these need a reducer signal that doesn't exist, SKIP that sub-item and note it — do not change the reducer.

- [ ] **Step 4: Build + commit**

Run: `tuist build FeatureKit` → `Build Succeeded`.
```bash
git add Sources/FeatureKit/Game/WorldCupView.swift Sources/FeatureKit/Game/CardFlipView.swift
git commit -m "feat(game): world cup pick motion + dots, card flip perspective + match feedback

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Result card stamp-in + full verification

**Files:**
- Modify: `Sources/FeatureKit/Game/ResultCard.swift`

- [ ] **Step 1: Stamp-in entrance**

Add `@State private var stamped = false` and apply to the card's main `VStack`:
```swift
            .scaleEffect(stamped ? 1 : 1.15)
            .rotationEffect(.degrees(stamped ? 0 : -4))
            .opacity(stamped ? 1 : 0)
            .task {
                withAnimation(.interpolatingSpring(stiffness: 210, damping: 14)) { stamped = true }
            }
```
(Keep the existing ConfettiBurst, StickerTile + WashiTape, the rich info rows from the previous round, and both buttons.)

- [ ] **Step 2: Build module + app + FULL suite**

Run: `tuist generate --no-open && tuist build FeatureKit`
App: `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' -skipMacroValidation 2>&1 | tail -3`
Full suite: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -skipMacroValidation 2>&1 | tail -6`
Expected: `Build Succeeded`, `BUILD SUCCEEDED`, `** TEST SUCCEEDED **` — **all existing tests unchanged and passing** (this pass touched no reducers).

- [ ] **Step 3: Commit**

```bash
git add Sources/FeatureKit/Game/ResultCard.swift
git commit -m "feat(game): stamp-in entrance for the result card

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review Notes (against spec)

- **Spec §1 hub** (no banner, status strip, tighter cards + lock badge, full-width group row, stagger) → Task 1 (+ 4-language keys).
- **Spec §2 gacha** (shake, shine, squash, sparkles) → Task 2. **roulette** (separators, blur, overshoot, pulse) → Task 3. **world cup** (pick motion, dots, VS pop) + **card flip** (perspective, match glow, mismatch shake) → Task 4. **result card** stamp-in → Task 5.
- **Spec §3 view-only** → no task touches a reducer/state/action or any test; the suite is verified untouched in Task 5.
- **Spec §4 testing** → full suite in Task 5; hub screenshot by the controller; game feel device-verified by the user.

## Notes for the implementer

- **Read before editing; keep it surgical.** These views are hand-tuned; anything not named in your task must survive byte-for-byte in behavior.
- Always `-skipMacroValidation`. Booted sim UDID `3B1E5795-617D-4955-8048-0CC8AD03BE95` (else `xcrun simctl list devices booted`).
- No `Math.random`/`Date()` in animation math — keep it deterministic (index-based).
- If a polish item would require a reducer change, SKIP it and say so in your report.
- Games need real cutouts to play; the simulator can't create them (Vision), so animations are build-verified here and device-verified by the user.
