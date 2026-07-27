# Collection Wall v2 (Flip + Parallax) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the pushed meal-detail with an in-place sticker flip (front = cutout, back = 가게/날짜/한줄평 + delete) and add a subtle gyro parallax to the collection wall.

**Architecture:** `CollectionFeature` gains flip state + a cutout→meal-info lookup; `cutoutTapped` toggles the flip; `RootFeature` stops intercepting `cutoutTapped` for push (MealDetail infra kept dormant). A view-only `ParallaxMotion` (CoreMotion) + `.parallax()` modifier drives the tilt. Surgical edits to the existing (evolved) files.

**Tech Stack:** SwiftUI + CoreMotion, TCA 1.26, existing kitsch/pastel DesignSystem, iOS 18, Swift 6.

## Global Constraints

- Surgical: do NOT change multi-select delete, streak, profile, achievements, recap, or widget flows. Keep `MealDetailFeature`/`View` + their tests (dormant).
- Korean UI + `L10n`; English comments; light mode.
- Build `tuist build FeatureKit`; tests `xcodebuild test ... -only-testing:<Bundle>/<Class> -skipMacroValidation`; app build via `FoodDiary` scheme `-skipMacroValidation`. Regenerate after adding files. Never `tuist install`; do not edit `Project.swift`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Task 1: `ParallaxMotion` + `.parallax()` modifier (view-only)

**Files:**
- Create: `Sources/FeatureKit/DesignSystem/ParallaxMotion.swift`

**Interfaces:**
- Produces: `@Observable final class ParallaxMotion { var tiltX: Double; var tiltY: Double; func start(); func stop() }` and `extension View { func parallax(_ strength: CGFloat, motion: ParallaxMotion) -> some View }`.
- No sensor (simulator) → `tiltX/tiltY` stay 0.

- [ ] **Step 1: Write the file**

```swift
import SwiftUI
import CoreMotion

@MainActor
@Observable
public final class ParallaxMotion {
    public private(set) var tiltX: Double = 0   // roll, normalized -1...1
    public private(set) var tiltY: Double = 0   // pitch, normalized -1...1

    @ObservationIgnored private let manager = CMMotionManager()

    public init() {}

    public func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            // Clamp to a gentle range so the wall drifts subtly.
            self.tiltX = max(-1, min(1, m.attitude.roll / 0.8))
            self.tiltY = max(-1, min(1, m.attitude.pitch / 0.8))
        }
    }

    public func stop() { manager.stopDeviceMotionUpdates() }
}

public extension View {
    func parallax(_ strength: CGFloat, motion: ParallaxMotion) -> some View {
        offset(x: CGFloat(motion.tiltX) * strength, y: CGFloat(motion.tiltY) * strength)
            .shadow(
                color: Color(.sRGB, red: 150 / 255, green: 120 / 255, blue: 180 / 255, opacity: 0.10),
                radius: 8,
                x: CGFloat(-motion.tiltX) * strength * 0.6,
                y: CGFloat(-motion.tiltY) * strength * 0.6
            )
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `tuist generate --no-open && tuist build FeatureKit`
Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add Sources/FeatureKit/DesignSystem/ParallaxMotion.swift
git commit -m "feat(design): ParallaxMotion + .parallax() modifier (CoreMotion)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Flip logic — `CollectionFeature` + `RootFeature` + tests

**Files:**
- Modify: `Sources/FeatureKit/Collection/CollectionFeature.swift`
- Modify: `Sources/FeatureKit/Root/RootFeature.swift`
- Modify: `Tests/FeatureKitTests/CollectionFeatureTests.swift` (add flip + mealInfo tests; keep existing)
- Modify: `Tests/FeatureKitTests/RootFeatureTests.swift` (replace the push test)

**Interfaces:**
- Produces: `struct CutoutMealInfo: Equatable, Sendable { let placeName: String; let dateText: String; let memo: String }`;
  `CollectionFeature.State.flippedCutoutID: UUID?`, `.cutoutMealInfo: [UUID: CutoutMealInfo]`;
  `CollectionFeature.Action.mealInfoLoaded([UUID: CutoutMealInfo])`. `cutoutTapped` toggles the flip.

- [ ] **Step 1: Add failing tests**

Append to `Tests/FeatureKitTests/CollectionFeatureTests.swift` (inside the class):
```swift
    @MainActor
    func test_cutoutTapped_togglesFlip() async {
        let id = UUID()
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.cutoutTapped(id)) { $0.flippedCutoutID = id }
        await store.send(.cutoutTapped(id)) { $0.flippedCutoutID = nil }
    }
```
Replace `Tests/FeatureKitTests/RootFeatureTests.swift`'s `test_cutoutTapped_pushesMealDetail` body with a non-push assertion:
```swift
    @MainActor
    func test_cutoutTapped_flipsInChild_doesNotPush() async {
        let cutoutID = UUID()
        let store = TestStore(initialState: RootFeature.State()) {
            RootFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.collection(.cutoutTapped(cutoutID)))
        XCTAssertEqual(store.state.collection.flippedCutoutID, cutoutID)
        XCTAssertTrue(store.state.path.isEmpty)
    }
```
(Rename the function; keep `test_tabChanged_updatesTab` as is. Remove any now-unused `persistence.mealByCutout` override in the old test.)

- [ ] **Step 2: Run to verify failure**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/CollectionFeatureTests/test_cutoutTapped_togglesFlip -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — `value ... has no member 'flippedCutoutID'`.

- [ ] **Step 3: Edit `CollectionFeature.swift`**

Add the value type near the top (after imports):
```swift
public struct CutoutMealInfo: Equatable, Sendable {
    public let placeName: String
    public let dateText: String
    public let memo: String
    public init(placeName: String, dateText: String, memo: String) {
        self.placeName = placeName; self.dateText = dateText; self.memo = memo
    }
}
```
In `State`, add (after `selectedCutoutIDs`):
```swift
        public var flippedCutoutID: UUID?
        public var cutoutMealInfo: [UUID: CutoutMealInfo] = [:]
```
In `Action`, add:
```swift
        case mealInfoLoaded([UUID: CutoutMealInfo])
```
Change the `.onAppear` case's `.run` to also load meal info (merge a second effect); simplest: after `cutoutsLoaded`, in a merged effect load meals. Replace the `.onAppear` case body with:
```swift
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let cutouts = try await persistence.allCutouts()
                    await send(.cutoutsLoaded(cutouts))
                    let meals = (try? await persistence.allMeals()) ?? []
                    var info: [UUID: CutoutMealInfo] = [:]
                    for meal in meals {
                        let dateText = meal.eatenAt.formatted(.dateTime.month().day())
                        for c in meal.cutouts {
                            info[c.id] = CutoutMealInfo(
                                placeName: meal.place?.name ?? "",
                                dateText: dateText,
                                memo: meal.memo
                            )
                        }
                    }
                    await send(.mealInfoLoaded(info))
                } catch: { _, send in
                    await send(.cutoutsLoaded([]))
                }
```
Add a case (next to `cutoutsLoaded`):
```swift
            case let .mealInfoLoaded(info):
                state.cutoutMealInfo = info
                return .none
```
Replace the `.cutoutTapped` case:
```swift
            case let .cutoutTapped(id):
                state.flippedCutoutID = (state.flippedCutoutID == id) ? nil : id
                return .none
```
(Leave everything else — editing/selection/delete/streak/achievements/recap/profile — unchanged.)

- [ ] **Step 4: Edit `RootFeature.swift`** — remove the push interception

Delete the entire case:
```swift
            case let .collection(.cutoutTapped(cutoutID)):
                return .run { send in
                    if let meal = try await persistence.mealByCutout(cutoutID) {
                        await send(.pushDetail(meal.id))
                    }
                }
```
Leave `pushDetail`, `path`, the `MealDetailFeature` scope, `.forEach(\.path...)`, and the `.path(.element(deleted))` handler untouched (dormant). The final catch-all `case .collection, .capture, .gameHub, .foodMap, .path: return .none` now also absorbs `.collection(.cutoutTapped)` (which the `CollectionFeature` scope already handled to flip).

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/CollectionFeatureTests -only-testing:FeatureKitTests/RootFeatureTests -skipMacroValidation 2>&1 | tail -6`
Expected: `** TEST SUCCEEDED **` (flip toggle, mealInfo, non-push, tabChanged, plus all existing CollectionFeature tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Collection/CollectionFeature.swift Sources/FeatureKit/Root/RootFeature.swift Tests/FeatureKitTests/CollectionFeatureTests.swift Tests/FeatureKitTests/RootFeatureTests.swift
git commit -m "feat(featurekit): flip cutout in place instead of pushing detail

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `CollectionView` flip UI + parallax + full verification

**Files:**
- Modify: `Sources/FeatureKit/Collection/CollectionView.swift`

**Interfaces:**
- Consumes: `CollectionFeature` (`flippedCutoutID`, `cutoutMealInfo`, `cutoutTapped`, `deleteCutoutsConfirmed`), `ParallaxMotion`/`.parallax`, existing DesignSystem.

- [ ] **Step 1: Add a `@State private var motion = ParallaxMotion()`** to `CollectionView` and start/stop it. In the `.task { ... }` block (which already sends onAppear/streakOnAppear/profileCheck), add `motion.start()`. (No explicit stop needed; the manager idles when the view is gone.)

- [ ] **Step 2: Replace the grid cell with a flip container + parallax.** In the `LazyVGrid`'s `ForEach`, change the cell so the label is a flip of front/back and the whole tile gets `.parallax`. Replace the `Button { ... } label: { StickerTile(...) ...overlays... }` label content with a flip:

```swift
                        Button {
                            store.send(
                                store.isEditing
                                    ? .selectionToggled(cutout.id)
                                    : .cutoutTapped(cutout.id)
                            )
                        } label: {
                            let isFlipped = store.flippedCutoutID == cutout.id
                            ZStack {
                                // FRONT
                                StickerTile(tint: .rotating(index)) {
                                    CutoutImage(fileName: cutout.fileName)
                                }
                                .overlay(alignment: .topTrailing) {
                                    if store.isEditing {
                                        Image(systemName:
                                            store.selectedCutoutIDs.contains(cutout.id)
                                                ? "checkmark.circle.fill" : "circle")
                                        .font(.title2.bold())
                                        .foregroundStyle(
                                            store.selectedCutoutIDs.contains(cutout.id)
                                                ? Color.appCherry : Color.appMuted)
                                        .padding(7)
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    if let symbol = CutoutDecoration(label: cutout.label).symbol {
                                        KitschIcon(symbol, tint: .appPinkInk, background: .appPink, size: 34)
                                            .padding(5)
                                    }
                                }
                                .opacity(isFlipped ? 0 : 1)

                                // BACK
                                cutoutBack(cutout)
                                    .opacity(isFlipped ? 1 : 0)
                                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                            }
                            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                            .rotationEffect(.degrees(index.isMultiple(of: 3) ? -1.2 : index.isMultiple(of: 2) ? 1 : 0))
                            .opacity(
                                store.isEditing && !store.selectedCutoutIDs.contains(cutout.id) ? 0.62 : 1
                            )
                            .parallax(8, motion: motion)
                        }
                        .buttonStyle(KitschPressStyle())
                        .contextMenu { /* unchanged: 기록 보기 -> cutoutTapped, 여러 개 선택, 삭제 */ } preview: { /* unchanged */ }
```
(Keep the existing `.contextMenu { … } preview: { … }` block exactly as it is.)

- [ ] **Step 3: Add the `cutoutBack` helper** to `CollectionView`:

```swift
    @ViewBuilder
    private func cutoutBack(_ cutout: CutoutSnapshot) -> some View {
        let info = store.cutoutMealInfo[cutout.id]
        VStack(alignment: .leading, spacing: 6) {
            Text(info?.placeName.isEmpty == false ? info!.placeName : "기록")
                .font(.appSection).foregroundStyle(.appInk).lineLimit(1)
            if let date = info?.dateText, !date.isEmpty {
                Text(date).font(.appCaption).foregroundStyle(.appMuted)
            }
            if let memo = info?.memo, !memo.isEmpty {
                Text("\u{201C}\(memo)\u{201D}").font(.appCaption).foregroundStyle(.appInk).lineLimit(3)
            }
            Spacer(minLength: 0)
            Button {
                store.send(.deleteCutoutsConfirmed([cutout.id]))
            } label: {
                Label("삭제", systemImage: "trash")
                    .font(.appCaption).foregroundStyle(.appPinkInk)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))
        .softShadow()
    }
```

- [ ] **Step 4: Build module + app + full suite**

Run: `tuist generate --no-open && tuist build FeatureKit`
App: `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' -skipMacroValidation 2>&1 | tail -3`
Full suite: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -skipMacroValidation 2>&1 | tail -6`
Expected: `Build Succeeded`, `BUILD SUCCEEDED`, `** TEST SUCCEEDED **` (all existing tests + the new flip/mealInfo/non-push tests).

- [ ] **Step 5: Simulator visual check (controller)**

Build for a booted sim, install, launch; complete onboarding if it gates; add a cutout is not possible in sim (Vision), so the flip is verified with the empty-state chrome + build. The controller confirms the wall renders and no regression. (Flip/parallax with real data is device-verified by the user.)

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Collection/CollectionView.swift
git commit -m "feat(featurekit): flip sticker back + parallax on collection wall

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review Notes (against spec)

- **Spec §3 flip state + mealInfo + cutoutTapped-toggle + RootFeature push removal** → Task 2 (with tests: flip toggle, mealInfo load, non-push, plus existing kept green).
- **Spec §4 flip UI (front/back rotation3DEffect, delete on back reuses deleteCutoutsConfirmed)** → Task 3.
- **Spec §5 parallax (view-only CoreMotion)** → Task 1 + applied in Task 3.
- **Spec §2 surgical**: multi-select/streak/profile/achievements/recap/widget untouched; `MealDetailFeature` kept dormant.
- **Type consistency:** `CutoutMealInfo` fields + `flippedCutoutID`/`cutoutMealInfo`/`mealInfoLoaded` names consistent across feature/view/tests.

## Notes for the implementer

- These files are large and recently evolved — apply the edits SURGICALLY (insert the named fields/cases; do not rewrite whole files or touch unrelated logic). Read the current file before each edit.
- Always `-skipMacroValidation`. Booted sim UDID `3B1E5795-617D-4955-8048-0CC8AD03BE95` (else `xcrun simctl list devices booted`).
- Parallax is felt only on device; in the simulator `tiltX/tiltY` stay 0 (no offset) — that's expected.
- If a symbol (`AppRadius`, `KitschIcon`, `CutoutDecoration`, `L10n`) differs from what's shown, match the current codebase spelling.
