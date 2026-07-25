# Achievements (음식 도감) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An achievements "도감" sheet (badges unlocked from cutout/place/meal counts) opened from a 🏆 button on the Collection screen.

**Architecture:** New `Sources/FeatureKit/Achievements/` with an `Achievement` model + catalog, `AchievementsFeature`, and `AchievementsView`. `CollectionFeature` gains a presented child + button action; `CollectionView` gets the 🏆 button + sheet. Reuses `persistence.allCutouts`/`allMeals`. No Models/other-client changes.

**Tech Stack:** SwiftUI, TCA 1.26, pastel DesignSystem, iOS 18, Swift 6.

## Global Constraints

- Additive; do not change Models, other clients, or the Capture/MealDetail/Game/Map reducers or their tests. `CollectionFeatureTests`' existing assertions must still pass (only new cases added).
- Korean UI strings; English comments; light mode; pastel DesignSystem.
- Build module `tuist build FeatureKit`; test `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:<Bundle>/<Class> -skipMacroValidation`; app build via `FoodDiary` scheme with `-skipMacroValidation`. Regenerate after adding files. Never `tuist install` / edit `Project.swift`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Task 1: `Achievement` model + `AchievementsFeature`

**Files:**
- Create: `Sources/FeatureKit/Achievements/AchievementsFeature.swift`
- Test: `Tests/FeatureKitTests/AchievementsFeatureTests.swift`

**Interfaces:**
- Consumes: `PersistenceClient.allCutouts`/`allMeals`, `MealSnapshot`, `PlaceInfo`.
- Produces:
  - `struct Achievement: Equatable, Identifiable { let id: String; let title: String; let emoji: String; let target: Int; let current: Int; var unlocked: Bool; var progress: Double }`
  - `@Reducer struct AchievementsFeature` with `@ObservableState struct State: Equatable { var cutoutCount; var mealCount; var placeCount; var achievements: [Achievement]; var unlockedCount: Int; init() }` and `enum Action: Equatable { case onAppear; case statsLoaded(cutouts: Int, meals: Int, places: Int); case close }`.

- [ ] **Step 1: Write the failing test**

`Tests/FeatureKitTests/AchievementsFeatureTests.swift`:
```swift
import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class AchievementsFeatureTests: XCTestCase {
    @MainActor
    func test_onAppear_loadsStats_andComputesUnlocks() async {
        let cutouts = (0..<10).map {
            CutoutSnapshot(id: UUID(), fileName: "\($0).png", createdAt: Date(), label: nil)
        }
        let meals = [
            MealSnapshot(id: UUID(), eatenAt: Date(),
                         place: PlaceInfo(id: "p1", name: "A", address: ""),
                         memo: "", rating: nil, cutouts: [])
        ]
        let store = TestStore(initialState: AchievementsFeature.State()) {
            AchievementsFeature()
        } withDependencies: {
            $0.persistence.allCutouts = { cutouts }
            $0.persistence.allMeals = { meals }
        }

        await store.send(.onAppear)
        await store.receive(\.statsLoaded) {
            $0.cutoutCount = 10
            $0.mealCount = 1
            $0.placeCount = 1
        }
        let a = store.state.achievements
        XCTAssertTrue(a.first { $0.id == "cut1" }!.unlocked)
        XCTAssertTrue(a.first { $0.id == "cut10" }!.unlocked)
        XCTAssertFalse(a.first { $0.id == "cut50" }!.unlocked)
        XCTAssertTrue(a.first { $0.id == "plc1" }!.unlocked)
        XCTAssertFalse(a.first { $0.id == "plc5" }!.unlocked)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/AchievementsFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — `cannot find 'AchievementsFeature'`.

- [ ] **Step 3: Write `AchievementsFeature.swift`**

```swift
import ComposableArchitecture
import Foundation
import Models
import ClientKit

public struct Achievement: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let emoji: String
    public let target: Int
    public let current: Int
    public var unlocked: Bool { current >= target }
    public var progress: Double { target == 0 ? 1 : min(1, Double(current) / Double(target)) }
}

enum AchievementMetric { case cutouts, places, meals }

private struct AchievementDef {
    let id: String; let title: String; let emoji: String
    let metric: AchievementMetric; let target: Int
}

private let achievementCatalog: [AchievementDef] = [
    .init(id: "cut1", title: "첫 누끼", emoji: "🍽", metric: .cutouts, target: 1),
    .init(id: "cut10", title: "누끼 10개", emoji: "🥉", metric: .cutouts, target: 10),
    .init(id: "cut50", title: "누끼 50개", emoji: "🥈", metric: .cutouts, target: 50),
    .init(id: "cut100", title: "누끼 100개", emoji: "🥇", metric: .cutouts, target: 100),
    .init(id: "plc1", title: "첫 맛집", emoji: "📍", metric: .places, target: 1),
    .init(id: "plc5", title: "맛집 5곳", emoji: "🗺️", metric: .places, target: 5),
    .init(id: "plc10", title: "맛집 10곳", emoji: "🌏", metric: .places, target: 10),
    .init(id: "meal30", title: "기록 30개", emoji: "📔", metric: .meals, target: 30),
]

func makeAchievements(cutouts: Int, places: Int, meals: Int) -> [Achievement] {
    achievementCatalog.map { def in
        let current: Int
        switch def.metric {
        case .cutouts: current = cutouts
        case .places: current = places
        case .meals: current = meals
        }
        return Achievement(id: def.id, title: def.title, emoji: def.emoji,
                           target: def.target, current: current)
    }
}

@Reducer
public struct AchievementsFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutoutCount = 0
        public var mealCount = 0
        public var placeCount = 0
        public init() {}

        public var achievements: [Achievement] {
            makeAchievements(cutouts: cutoutCount, places: placeCount, meals: mealCount)
        }
        public var unlockedCount: Int { achievements.filter(\.unlocked).count }
    }

    public enum Action: Equatable {
        case onAppear
        case statsLoaded(cutouts: Int, meals: Int, places: Int)
        case close
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let cutouts = try await persistence.allCutouts().count
                    let meals = try await persistence.allMeals()
                    let places = Set(meals.compactMap { $0.place?.id }).count
                    await send(.statsLoaded(cutouts: cutouts, meals: meals.count, places: places))
                }
            case let .statsLoaded(cutouts, meals, places):
                state.cutoutCount = cutouts
                state.mealCount = meals
                state.placeCount = places
                return .none
            case .close:
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/AchievementsFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Sources/FeatureKit/Achievements/AchievementsFeature.swift Tests/FeatureKitTests/AchievementsFeatureTests.swift
git commit -m "feat(featurekit): achievements feature + catalog

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `AchievementsView`

**Files:**
- Create: `Sources/FeatureKit/Achievements/AchievementsView.swift`

**Interfaces:**
- Consumes: `AchievementsFeature`, DesignSystem tokens/`SoftCard`.
- Produces: `public struct AchievementsView: View { init(store: StoreOf<AchievementsFeature>) }`.

- [ ] **Step 1: Write the file**

```swift
import SwiftUI
import ComposableArchitecture

public struct AchievementsView: View {
    @Bindable var store: StoreOf<AchievementsFeature>
    public init(store: StoreOf<AchievementsFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("음식 도감 🏆").font(.appDisplay).foregroundStyle(.appInk)
                        Spacer()
                        Button { store.send(.close) } label: {
                            Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.appMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("\(store.unlockedCount) / \(store.achievements.count) 달성")
                        .font(.appSection).foregroundStyle(.appBlueInk)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(store.achievements) { a in badge(a) }
                    }
                }
                .padding(18)
            }
        }
        .task { store.send(.onAppear) }
    }

    private func badge(_ a: Achievement) -> some View {
        SoftCard {
            VStack(spacing: 8) {
                Text(a.emoji)
                    .font(.system(size: 40))
                    .opacity(a.unlocked ? 1 : 0.35)
                    .grayscale(a.unlocked ? 0 : 1)
                Text(a.title).font(.appSection)
                    .foregroundStyle(a.unlocked ? Color.appInk : Color.appMuted)
                if a.unlocked {
                    Text("달성!").font(.appCaption).foregroundStyle(.appPinkInk)
                } else {
                    ProgressView(value: a.progress).tint(.appBlue)
                    Text("\(a.current)/\(a.target)").font(.appCaption).foregroundStyle(.appMuted)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `tuist generate --no-open && tuist build FeatureKit`
Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add Sources/FeatureKit/Achievements/AchievementsView.swift
git commit -m "feat(featurekit): AchievementsView badge grid

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Collection entry (button + sheet) + full verification

**Files:**
- Modify: `Sources/FeatureKit/Collection/CollectionFeature.swift`
- Modify: `Sources/FeatureKit/Collection/CollectionView.swift`
- Test: `Tests/FeatureKitTests/CollectionFeatureTests.swift` (add cases; keep existing)

**Interfaces:**
- Consumes: `AchievementsFeature`, `AchievementsView`.
- CollectionFeature gains `@Presents var achievements: AchievementsFeature.State?`, `Action.achievementsButtonTapped`, `Action.achievements(PresentationAction<AchievementsFeature.Action>)`, and `.ifLet(\.$achievements, action: \.achievements) { AchievementsFeature() }`. On `.achievements(.presented(.close))` → set nil.

- [ ] **Step 1: Add the new test cases (keep the existing one)**

Append to `Tests/FeatureKitTests/CollectionFeatureTests.swift` (inside the class):
```swift
    @MainActor
    func test_achievementsButton_presentsAndDismisses() async {
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.achievementsButtonTapped) {
            $0.achievements = AchievementsFeature.State()
        }
        await store.send(.achievements(.presented(.close))) {
            $0.achievements = nil
        }
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/CollectionFeatureTests/test_achievementsButton_presentsAndDismisses -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — `type 'CollectionFeature.Action' has no member 'achievementsButtonTapped'`.

- [ ] **Step 3: Extend `CollectionFeature.swift`**

Add to `State` (after `isLoading`):
```swift
        @Presents public var achievements: AchievementsFeature.State?
```
Add to `Action`:
```swift
        case achievementsButtonTapped
        case achievements(PresentationAction<AchievementsFeature.Action>)
```
In the `Reduce` switch, add:
```swift
            case .achievementsButtonTapped:
                state.achievements = AchievementsFeature.State()
                return .none
            case .achievements(.presented(.close)):
                state.achievements = nil
                return .none
            case .achievements:
                return .none
```
And add `.ifLet` after the `Reduce { … }` closing brace:
```swift
        .ifLet(\.$achievements, action: \.achievements) {
            AchievementsFeature()
        }
```
> Note: `CollectionFeature.Action` currently conforms to `Equatable`. `PresentationAction<AchievementsFeature.Action>` is Equatable (AchievementsFeature.Action is Equatable), so the enum stays Equatable — keep the `Equatable` conformance.

- [ ] **Step 4: Extend `CollectionView.swift`** — 🏆 button + sheet

Add a top-trailing button overlay and a sheet. Inside `CollectionView.body`, after the `ScreenScaffold { … }` block's `.task { store.send(.onAppear) }` chain, add:
```swift
        .overlay(alignment: .topTrailing) {
            Button { store.send(.achievementsButtonTapped) } label: {
                Text("🏆").font(.title2)
                    .padding(10).background(Color.appCard, in: Circle()).softShadow()
            }
            .buttonStyle(.plain)
            .padding(.trailing, 18).padding(.top, 6)
        }
        .sheet(item: $store.scope(state: \.achievements, action: \.achievements)) { achStore in
            AchievementsView(store: achStore)
        }
```
(Keep the rest of `CollectionView` unchanged.)

- [ ] **Step 5: Run the new test + full suite**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/CollectionFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: both CollectionFeature tests pass.
Then app build + full suite:
`xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' -skipMacroValidation 2>&1 | tail -3`
`xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -skipMacroValidation 2>&1 | tail -6`
Expected: `BUILD SUCCEEDED`, `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Collection/CollectionFeature.swift Sources/FeatureKit/Collection/CollectionView.swift Tests/FeatureKitTests/CollectionFeatureTests.swift
git commit -m "feat(featurekit): open achievements sheet from collection

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review Notes (against spec)

- **Spec §3 stats** → Task 1 `onAppear` (allCutouts count + allMeals + distinct places).
- **Spec §4 Achievement model + catalog** → Task 1.
- **Spec §5 AchievementsFeature/View** → Tasks 1–2. **Entry (Collection 🏆 + sheet)** → Task 3.
- **Spec §6 testing** → AchievementsFeature test (unlock flags), CollectionFeature present/dismiss test (existing onAppear test kept), build+screenshot in Task 3.
- **Type consistency:** `Achievement.id` strings match between the catalog and the test assertions (`cut1`/`cut10`/`cut50`/`plc1`/`plc5`); `achievements` scope/action names consistent across CollectionFeature/View.

## Notes for the implementer

- Always `-skipMacroValidation`. Booted sim UDID `3B1E5795-617D-4955-8048-0CC8AD03BE95` (else `xcrun simctl list devices booted`).
- Do not change the existing `test_onAppear_loadsCutouts` assertions.
- If `MealSnapshot`/`CutoutSnapshot` unresolved in a file, add `import Models`.
