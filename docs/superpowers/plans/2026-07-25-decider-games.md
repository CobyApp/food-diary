# Decider Game Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "🎲 뭐먹지" tab with a hub and four decider mini-games (Gacha, Food World Cup, Card Flip, Roulette) that pick a meal from the user's collected food cutouts.

**Architecture:** New `RandomClient` (ClientKit, injectable → testable). New `Sources/FeatureKit/Game/` with four game reducers, a shared `ResultCard`, and a `GameHubFeature` that presents a game via a `@Reducer enum GameDestination`. `RootFeature` gains a `.game` tab. Existing reducers/models untouched (only RootFeature extended with the tab).

**Tech Stack:** SwiftUI, TCA 1.26 (`@Reducer`, `@Presents`, enum reducers), pastel DesignSystem, iOS 18, Swift 6.

## Global Constraints

- Reuse `persistence.allCutouts()` / `persistence.mealByCutout(id)` and the pastel DesignSystem; do not change Models, ClientKit persistence, Capture/Collection/MealDetail reducers, or their tests.
- Randomness only via `RandomClient` (never call `.shuffled()`/`.randomElement()` inside a reducer) so games are TestStore-deterministic.
- Korean UI strings; English comments; light mode.
- Build module: `tuist build FeatureKit`. Run a test target: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:<Bundle>/<Class> -skipMacroValidation`. Full suite: same without `-only-testing`. App build via `FoodDiary` scheme. Regenerate after adding files: `tuist generate --no-open`. Never run `tuist install` or edit `Project.swift`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Task 1: `RandomClient` (ClientKit)

**Files:**
- Create: `Sources/ClientKit/RandomClient.swift`
- Test: `Tests/ClientKitTests/RandomClientTests.swift`

**Interfaces:**
- Produces: `@DependencyClient struct RandomClient: Sendable { var shuffled: @Sendable ([CutoutSnapshot]) -> [CutoutSnapshot]; var pick: @Sendable ([CutoutSnapshot]) -> CutoutSnapshot? }`, `DependencyValues.random`, live/test/preview values.

- [ ] **Step 1: Write the failing test**

`Tests/ClientKitTests/RandomClientTests.swift`:
```swift
import XCTest
import Models
@testable import ClientKit

final class RandomClientTests: XCTestCase {
    private func snap(_ id: String) -> CutoutSnapshot {
        CutoutSnapshot(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000\(id)")!,
                       fileName: "\(id).png", createdAt: Date(timeIntervalSince1970: 0), label: nil)
    }

    func test_liveShuffled_preservesElements() {
        let items = [snap("01"), snap("02"), snap("03")]
        let out = RandomClient.liveValue.shuffled(items)
        XCTAssertEqual(out.count, 3)
        XCTAssertEqual(Set(out.map(\.id)), Set(items.map(\.id)))
    }

    func test_livePick_returnsMemberOrNil() {
        XCTAssertNil(RandomClient.liveValue.pick([]))
        let items = [snap("01")]
        XCTAssertEqual(RandomClient.liveValue.pick(items)?.id, items[0].id)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:ClientKitTests/RandomClientTests -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — `cannot find 'RandomClient'`.

- [ ] **Step 3: Write the implementation**

`Sources/ClientKit/RandomClient.swift`:
```swift
import Dependencies
import DependenciesMacros
import Models

@DependencyClient
public struct RandomClient: Sendable {
    public var shuffled: @Sendable (_ items: [CutoutSnapshot]) -> [CutoutSnapshot] = { $0 }
    public var pick: @Sendable (_ items: [CutoutSnapshot]) -> CutoutSnapshot?
}

extension RandomClient: DependencyKey {
    public static let liveValue = RandomClient(
        shuffled: { $0.shuffled() },
        pick: { $0.randomElement() }
    )
}

extension RandomClient: TestDependencyKey {
    // Deterministic: identity order, pick = first. Games inject their own for
    // exact assertions.
    public static let testValue = RandomClient(shuffled: { $0 }, pick: { $0.first })
    public static let previewValue = testValue
}

public extension DependencyValues {
    var random: RandomClient {
        get { self[RandomClient.self] }
        set { self[RandomClient.self] = newValue }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:ClientKitTests/RandomClientTests -skipMacroValidation 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Sources/ClientKit/RandomClient.swift Tests/ClientKitTests/RandomClientTests.swift
git commit -m "feat(clientkit): RandomClient for decider games

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Shared `ResultCard` view

**Files:**
- Create: `Sources/FeatureKit/Game/ResultCard.swift`

**Interfaces:**
- Consumes: `CutoutSnapshot`, DesignSystem (`StickerTile`, `PillButton`, tokens), `CutoutImage`.
- Produces: `struct ResultCard: View { init(cutout: CutoutSnapshot, place: String?, onAgain: @escaping () -> Void, onClose: @escaping () -> Void) }`

- [ ] **Step 1: Write the file**

`Sources/FeatureKit/Game/ResultCard.swift`:
```swift
import SwiftUI
import Models

struct ResultCard: View {
    let cutout: CutoutSnapshot
    let place: String?
    let onAgain: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("오늘은 여기! 🍜").font(.appTitle).foregroundStyle(.appInk)
            StickerTile(tint: .pink) { CutoutImage(fileName: cutout.fileName) }
                .frame(width: 210, height: 210)
                .transition(.scale.combined(with: .opacity))
            Text(place ?? cutout.label ?? "맛있는 거")
                .font(.appDisplay).foregroundStyle(.appBlueInk)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                PillButton("다시 뽑기") { onAgain() }
                Button { onClose() } label: {
                    Text("닫기").font(.appSection).foregroundStyle(.appMuted)
                        .padding(.vertical, 14).padding(.horizontal, 22)
                        .background(Color.appCard).clipShape(Capsule()).softShadow()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `tuist generate --no-open && tuist build FeatureKit`
Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add Sources/FeatureKit/Game/ResultCard.swift
git commit -m "feat(featurekit): shared ResultCard for decider games

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Gacha game

**Files:**
- Create: `Sources/FeatureKit/Game/GachaFeature.swift`
- Create: `Sources/FeatureKit/Game/GachaView.swift`
- Test: `Tests/FeatureKitTests/GachaFeatureTests.swift`

**Interfaces:**
- Consumes: `RandomClient` (`\.random`), `PersistenceClient.mealByCutout` (`\.persistence`), `CutoutSnapshot`, `ResultCard`.
- Produces: `@Reducer struct GachaFeature` with `@ObservableState struct State: Equatable { var cutouts: [CutoutSnapshot]; var result: CutoutSnapshot?; var resultPlace: String?; var isSpinning: Bool; init(cutouts: [CutoutSnapshot]) }` and `enum Action: Equatable { case pullLever; case revealed(CutoutSnapshot); case placeLoaded(String?); case playAgain; case close }`. `GachaView(store:)`.

- [ ] **Step 1: Write the failing test**

`Tests/FeatureKitTests/GachaFeatureTests.swift`:
```swift
import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class GachaFeatureTests: XCTestCase {
    private func snap(_ n: Int) -> CutoutSnapshot {
        CutoutSnapshot(id: UUID(), fileName: "\(n).png", createdAt: Date(), label: "food\(n)")
    }

    @MainActor
    func test_pullLever_revealsPickedCutout_andLoadsPlace() async {
        let items = [snap(1), snap(2)]
        let picked = items[1]
        let store = TestStore(initialState: GachaFeature.State(cutouts: items)) {
            GachaFeature()
        } withDependencies: {
            $0.random.pick = { _ in picked }
            $0.persistence.mealByCutout = { _ in
                MealSnapshot(id: UUID(), eatenAt: Date(),
                             place: PlaceInfo(id: "p", name: "라멘집", address: ""),
                             memo: "", rating: nil, cutouts: [])
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pullLever) {
            $0.isSpinning = true
            $0.result = picked
        }
        await store.receive(\.placeLoaded) { $0.resultPlace = "라멘집" }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/GachaFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — `cannot find 'GachaFeature'`.

- [ ] **Step 3: Write `GachaFeature.swift`**

```swift
import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct GachaFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot]
        public var result: CutoutSnapshot?
        public var resultPlace: String?
        public var isSpinning = false
        public init(cutouts: [CutoutSnapshot]) { self.cutouts = cutouts }
    }

    public enum Action: Equatable {
        case pullLever
        case revealed(CutoutSnapshot)
        case placeLoaded(String?)
        case playAgain
        case close
    }

    @Dependency(\.random) var random
    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .pullLever:
                guard let pick = random.pick(state.cutouts) else { return .none }
                state.isSpinning = true
                state.result = pick
                state.resultPlace = nil
                return .run { send in
                    let place = try? await persistence.mealByCutout(pick.id)?.place?.name
                    await send(.placeLoaded(place ?? nil))
                }

            case let .revealed(cutout):
                state.result = cutout
                return .none

            case let .placeLoaded(place):
                state.resultPlace = place
                return .none

            case .playAgain:
                state.result = nil
                state.resultPlace = nil
                state.isSpinning = false
                return .none

            case .close:
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Write `GachaView.swift`**

```swift
import SwiftUI
import ComposableArchitecture

public struct GachaView: View {
    @Bindable var store: StoreOf<GachaFeature>
    public init(store: StoreOf<GachaFeature>) { self.store = store }

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            if let result = store.result {
                ResultCard(cutout: result, place: store.resultPlace,
                           onAgain: { store.send(.playAgain) },
                           onClose: { store.send(.close) })
            } else {
                VStack(spacing: 24) {
                    Text("🎰").font(.system(size: 90))
                    Text("가챠 뽑기").font(.appDisplay).foregroundStyle(.appInk)
                    Text("레버를 당겨 오늘의 메뉴를 뽑아요").font(.appBody).foregroundStyle(.appMuted)
                    PillButton("레버 당기기") { store.send(.pullLever) }
                        .padding(.horizontal, 60)
                    Button("닫기") { store.send(.close) }.foregroundStyle(.appMuted)
                }
                .padding(24)
            }
        }
        .animation(.spring(duration: 0.4), value: store.result)
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/GachaFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Game/GachaFeature.swift Sources/FeatureKit/Game/GachaView.swift Tests/FeatureKitTests/GachaFeatureTests.swift
git commit -m "feat(featurekit): gacha decider game

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Food World Cup game

**Files:**
- Create: `Sources/FeatureKit/Game/WorldCupFeature.swift`
- Create: `Sources/FeatureKit/Game/WorldCupView.swift`
- Test: `Tests/FeatureKitTests/WorldCupFeatureTests.swift`

**Interfaces:**
- Consumes: `RandomClient`, `PersistenceClient.mealByCutout`, `CutoutSnapshot`, `ResultCard`.
- Produces: `@Reducer struct WorldCupFeature` with `@ObservableState struct State: Equatable { var cutouts: [CutoutSnapshot]; var currentRound: [CutoutSnapshot]; var nextRound: [CutoutSnapshot]; var pairIndex: Int; var champion: CutoutSnapshot?; var championPlace: String?; init(cutouts: [CutoutSnapshot]); var currentPair: (CutoutSnapshot, CutoutSnapshot)?; var roundName: String }` and `enum Action: Equatable { case start; case pick(CutoutSnapshot); case placeLoaded(String?); case playAgain; case close }`.
- Bracket size = largest power of two ≤ `cutouts.count`, clamped to `2...16`.

- [ ] **Step 1: Write the failing test**

`Tests/FeatureKitTests/WorldCupFeatureTests.swift`:
```swift
import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class WorldCupFeatureTests: XCTestCase {
    private func snap(_ n: Int) -> CutoutSnapshot {
        CutoutSnapshot(id: UUID(), fileName: "\(n).png", createdAt: Date(), label: "f\(n)")
    }

    @MainActor
    func test_twoContenders_pickYieldsChampion() async {
        let items = [snap(1), snap(2), snap(3)] // bracket size 2
        let store = TestStore(initialState: WorldCupFeature.State(cutouts: items)) {
            WorldCupFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 } // deterministic order
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.start) {
            $0.currentRound = [items[0], items[1]]
            $0.pairIndex = 0
        }
        await store.send(.pick(items[0])) {
            $0.champion = items[0]
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/WorldCupFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — `cannot find 'WorldCupFeature'`.

- [ ] **Step 3: Write `WorldCupFeature.swift`**

```swift
import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct WorldCupFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot]
        public var currentRound: [CutoutSnapshot] = []
        public var nextRound: [CutoutSnapshot] = []
        public var pairIndex = 0
        public var champion: CutoutSnapshot?
        public var championPlace: String?
        public init(cutouts: [CutoutSnapshot]) { self.cutouts = cutouts }

        public var currentPair: (CutoutSnapshot, CutoutSnapshot)? {
            guard pairIndex + 1 < currentRound.count else { return nil }
            return (currentRound[pairIndex], currentRound[pairIndex + 1])
        }

        public var roundName: String {
            switch currentRound.count {
            case 2: return "결승"
            case 4: return "4강"
            case 8: return "8강"
            case 16: return "16강"
            default: return "\(currentRound.count)강"
            }
        }
    }

    public enum Action: Equatable {
        case start
        case pick(CutoutSnapshot)
        case placeLoaded(String?)
        case playAgain
        case close
    }

    @Dependency(\.random) var random
    @Dependency(\.persistence) var persistence

    public init() {}

    private func bracketSize(_ count: Int) -> Int {
        guard count >= 2 else { return 0 }
        var size = 1
        while size * 2 <= min(count, 16) { size *= 2 }
        return size
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .start:
                let size = bracketSize(state.cutouts.count)
                guard size >= 2 else { return .none }
                state.currentRound = Array(random.shuffled(state.cutouts).prefix(size))
                state.nextRound = []
                state.pairIndex = 0
                state.champion = nil
                state.championPlace = nil
                return .none

            case let .pick(winner):
                state.nextRound.append(winner)
                state.pairIndex += 2
                if state.pairIndex >= state.currentRound.count {
                    // round finished
                    if state.nextRound.count == 1 {
                        let champ = state.nextRound[0]
                        state.champion = champ
                        return .run { send in
                            let place = try? await persistence.mealByCutout(champ.id)?.place?.name
                            await send(.placeLoaded(place ?? nil))
                        }
                    }
                    state.currentRound = state.nextRound
                    state.nextRound = []
                    state.pairIndex = 0
                }
                return .none

            case let .placeLoaded(place):
                state.championPlace = place
                return .none

            case .playAgain:
                state.currentRound = []
                state.nextRound = []
                state.pairIndex = 0
                state.champion = nil
                state.championPlace = nil
                return .send(.start)

            case .close:
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Write `WorldCupView.swift`**

```swift
import SwiftUI
import ComposableArchitecture

public struct WorldCupView: View {
    @Bindable var store: StoreOf<WorldCupFeature>
    public init(store: StoreOf<WorldCupFeature>) { self.store = store }

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            if let champ = store.champion {
                ResultCard(cutout: champ, place: store.championPlace,
                           onAgain: { store.send(.playAgain) },
                           onClose: { store.send(.close) })
            } else if let pair = store.currentPair {
                VStack(spacing: 20) {
                    Text(store.roundName).font(.appDisplay).foregroundStyle(.appBlueInk)
                    contender(pair.0)
                    Text("VS").font(.appTitle).foregroundStyle(.appMuted)
                    contender(pair.1)
                    Button("닫기") { store.send(.close) }.foregroundStyle(.appMuted).padding(.top, 4)
                }
                .padding(24)
            } else {
                ProgressView().tint(.appBlue).task { store.send(.start) }
            }
        }
        .animation(.spring(duration: 0.35), value: store.pairIndex)
    }

    private func contender(_ cutout: CutoutSnapshot) -> some View {
        Button { store.send(.pick(cutout)) } label: {
            StickerTile(tint: .rotating(cutout.hashValue)) { CutoutImage(fileName: cutout.fileName) }
                .frame(maxWidth: .infinity).frame(height: 150)
        }
        .buttonStyle(.plain)
    }
}
```
> Note: `import Models` is provided transitively; if `CutoutSnapshot` is unresolved in the view, add `import Models`.

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/WorldCupFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Game/WorldCupFeature.swift Sources/FeatureKit/Game/WorldCupView.swift Tests/FeatureKitTests/WorldCupFeatureTests.swift
git commit -m "feat(featurekit): food world cup decider game

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Card Flip game

**Files:**
- Create: `Sources/FeatureKit/Game/CardFlipFeature.swift`
- Create: `Sources/FeatureKit/Game/CardFlipView.swift`
- Test: `Tests/FeatureKitTests/CardFlipFeatureTests.swift`

**Interfaces:**
- Consumes: `RandomClient`, `PersistenceClient.mealByCutout`, `CutoutSnapshot`, `ResultCard`.
- Produces: `@Reducer struct CardFlipFeature` with `@ObservableState struct State: Equatable { var cutouts: [CutoutSnapshot]; var cards: [CutoutSnapshot]; var revealedIndex: Int?; var resultPlace: String?; init(cutouts: [CutoutSnapshot]); var result: CutoutSnapshot? }` and `enum Action: Equatable { case start; case flip(Int); case placeLoaded(String?); case playAgain; case close }`. Lays up to 6 shuffled cards.

- [ ] **Step 1: Write the failing test**

`Tests/FeatureKitTests/CardFlipFeatureTests.swift`:
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
    func test_start_laysCards_flipSelectsCard() async {
        let items = [snap(1), snap(2), snap(3)]
        let store = TestStore(initialState: CardFlipFeature.State(cutouts: items)) {
            CardFlipFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.start) { $0.cards = items }
        await store.send(.flip(1)) { $0.revealedIndex = 1 }
        // result computed property returns cards[1]
        XCTAssertEqual(store.state.result?.id, items[1].id)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/CardFlipFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — `cannot find 'CardFlipFeature'`.

- [ ] **Step 3: Write `CardFlipFeature.swift`**

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
        public var resultPlace: String?
        public init(cutouts: [CutoutSnapshot]) { self.cutouts = cutouts }

        public var result: CutoutSnapshot? {
            guard let i = revealedIndex, cards.indices.contains(i) else { return nil }
            return cards[i]
        }
    }

    public enum Action: Equatable {
        case start
        case flip(Int)
        case placeLoaded(String?)
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
                state.resultPlace = nil
                return .none

            case let .flip(index):
                guard state.revealedIndex == nil, state.cards.indices.contains(index) else { return .none }
                state.revealedIndex = index
                let picked = state.cards[index]
                return .run { send in
                    let place = try? await persistence.mealByCutout(picked.id)?.place?.name
                    await send(.placeLoaded(place ?? nil))
                }

            case let .placeLoaded(place):
                state.resultPlace = place
                return .none

            case .playAgain:
                state.revealedIndex = nil
                state.resultPlace = nil
                return .send(.start)

            case .close:
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Write `CardFlipView.swift`**

```swift
import SwiftUI
import ComposableArchitecture
import Models

public struct CardFlipView: View {
    @Bindable var store: StoreOf<CardFlipFeature>
    public init(store: StoreOf<CardFlipFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 12)]

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            if let result = store.result {
                ResultCard(cutout: result, place: store.resultPlace,
                           onAgain: { store.send(.playAgain) },
                           onClose: { store.send(.close) })
            } else {
                VStack(spacing: 18) {
                    Text("카드 뒤집기 🃏").font(.appDisplay).foregroundStyle(.appInk)
                    Text("카드 하나를 골라 뒤집어요").font(.appBody).foregroundStyle(.appMuted)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(store.cards.enumerated()), id: \.offset) { index, _ in
                            Button { store.send(.flip(index)) } label: {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(Color.appTileBlue)
                                    .overlay(Text("?").font(.appDisplay).foregroundStyle(.appBlue))
                                    .aspectRatio(1, contentMode: .fit)
                                    .softShadow()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button("닫기") { store.send(.close) }.foregroundStyle(.appMuted)
                }
                .padding(24)
                .task { if store.cards.isEmpty { store.send(.start) } }
            }
        }
        .animation(.spring(duration: 0.4), value: store.revealedIndex)
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/CardFlipFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Game/CardFlipFeature.swift Sources/FeatureKit/Game/CardFlipView.swift Tests/FeatureKitTests/CardFlipFeatureTests.swift
git commit -m "feat(featurekit): card flip decider game

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Roulette/Slot game

**Files:**
- Create: `Sources/FeatureKit/Game/RouletteFeature.swift`
- Create: `Sources/FeatureKit/Game/RouletteView.swift`
- Test: `Tests/FeatureKitTests/RouletteFeatureTests.swift`

**Interfaces:**
- Consumes: `RandomClient`, `PersistenceClient.mealByCutout`, `CutoutSnapshot`, `ResultCard`.
- Produces: `@Reducer struct RouletteFeature` with `@ObservableState struct State: Equatable { var cutouts: [CutoutSnapshot]; var reel: [CutoutSnapshot]; var result: CutoutSnapshot?; var resultPlace: String?; var isSpinning: Bool; init(cutouts: [CutoutSnapshot]) }` and `enum Action: Equatable { case appear; case spin; case placeLoaded(String?); case playAgain; case close }`. `appear` builds the reel via `random.shuffled`.

- [ ] **Step 1: Write the failing test**

`Tests/FeatureKitTests/RouletteFeatureTests.swift`:
```swift
import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class RouletteFeatureTests: XCTestCase {
    private func snap(_ n: Int) -> CutoutSnapshot {
        CutoutSnapshot(id: UUID(), fileName: "\(n).png", createdAt: Date(), label: "f\(n)")
    }

    @MainActor
    func test_spin_setsPickedResult() async {
        let items = [snap(1), snap(2)]
        let picked = items[0]
        let store = TestStore(initialState: RouletteFeature.State(cutouts: items)) {
            RouletteFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.random.pick = { _ in picked }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.spin) {
            $0.isSpinning = true
            $0.result = picked
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/RouletteFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — `cannot find 'RouletteFeature'`.

- [ ] **Step 3: Write `RouletteFeature.swift`**

```swift
import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct RouletteFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot]
        public var reel: [CutoutSnapshot] = []
        public var result: CutoutSnapshot?
        public var resultPlace: String?
        public var isSpinning = false
        public init(cutouts: [CutoutSnapshot]) { self.cutouts = cutouts }
    }

    public enum Action: Equatable {
        case appear
        case spin
        case placeLoaded(String?)
        case playAgain
        case close
    }

    @Dependency(\.random) var random
    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appear:
                if state.reel.isEmpty {
                    // A longer reel for the scrolling visual.
                    state.reel = (0..<3).flatMap { _ in random.shuffled(state.cutouts) }
                }
                return .none

            case .spin:
                guard let pick = random.pick(state.cutouts) else { return .none }
                state.isSpinning = true
                state.result = pick
                state.resultPlace = nil
                return .run { send in
                    let place = try? await persistence.mealByCutout(pick.id)?.place?.name
                    await send(.placeLoaded(place ?? nil))
                }

            case let .placeLoaded(place):
                state.resultPlace = place
                return .none

            case .playAgain:
                state.result = nil
                state.resultPlace = nil
                state.isSpinning = false
                return .none

            case .close:
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Write `RouletteView.swift`**

```swift
import SwiftUI
import ComposableArchitecture
import Models

public struct RouletteView: View {
    @Bindable var store: StoreOf<RouletteFeature>
    public init(store: StoreOf<RouletteFeature>) { self.store = store }

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            if let result = store.result {
                ResultCard(cutout: result, place: store.resultPlace,
                           onAgain: { store.send(.playAgain) },
                           onClose: { store.send(.close) })
            } else {
                VStack(spacing: 18) {
                    Text("룰렛 슬롯 🎡").font(.appDisplay).foregroundStyle(.appInk)
                    ScrollView(.vertical) {
                        VStack(spacing: 10) {
                            ForEach(Array(store.reel.enumerated()), id: \.offset) { _, cutout in
                                StickerTile(tint: .rotating(cutout.hashValue)) {
                                    CutoutImage(fileName: cutout.fileName)
                                }
                                .frame(height: 90)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    PillButton("스핀!") { store.send(.spin) }.padding(.horizontal, 60)
                    Button("닫기") { store.send(.close) }.foregroundStyle(.appMuted)
                }
                .padding(24)
                .task { store.send(.appear) }
            }
        }
        .animation(.spring(duration: 0.4), value: store.result)
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/RouletteFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Game/RouletteFeature.swift Sources/FeatureKit/Game/RouletteView.swift Tests/FeatureKitTests/RouletteFeatureTests.swift
git commit -m "feat(featurekit): roulette/slot decider game

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: Game hub (destination enum + hub reducer + view)

**Files:**
- Create: `Sources/FeatureKit/Game/GameHubFeature.swift`
- Create: `Sources/FeatureKit/Game/GameHubView.swift`
- Test: `Tests/FeatureKitTests/GameHubFeatureTests.swift`

**Interfaces:**
- Consumes: `GachaFeature`, `WorldCupFeature`, `CardFlipFeature`, `RouletteFeature`, `PersistenceClient.allCutouts`, `CutoutSnapshot`.
- Produces:
  - `@Reducer enum GameDestination { case gacha(GachaFeature); case worldCup(WorldCupFeature); case cardFlip(CardFlipFeature); case roulette(RouletteFeature) }`
  - `@Reducer struct GameHubFeature` with `@ObservableState struct State: Equatable { var cutouts: [CutoutSnapshot] = []; @Presents var game: GameDestination.State? }` and `enum Action { case onAppear; case cutoutsLoaded([CutoutSnapshot]); case gameTapped(GameKind); case game(PresentationAction<GameDestination.Action>) }` with `enum GameKind: Equatable { case gacha, worldCup, cardFlip, roulette }`.
  - `GameHubView(store:)`.
- Closing: each game's `.close` action bubbles up via `.game(.presented(.<kind>(.close)))` → hub sets `game = nil`.

- [ ] **Step 1: Write the failing test**

`Tests/FeatureKitTests/GameHubFeatureTests.swift`:
```swift
import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class GameHubFeatureTests: XCTestCase {
    private func snap(_ n: Int) -> CutoutSnapshot {
        CutoutSnapshot(id: UUID(), fileName: "\(n).png", createdAt: Date(), label: "f\(n)")
    }

    @MainActor
    func test_onAppear_loadsCutouts() async {
        let items = [snap(1), snap(2)]
        let store = TestStore(initialState: GameHubFeature.State()) {
            GameHubFeature()
        } withDependencies: {
            $0.persistence.allCutouts = { items }
        }
        await store.send(.onAppear)
        await store.receive(\.cutoutsLoaded) { $0.cutouts = items }
    }

    @MainActor
    func test_gameTapped_presentsGachaWithPool() async {
        let items = [snap(1), snap(2)]
        let store = TestStore(initialState: GameHubFeature.State(cutouts: items)) {
            GameHubFeature()
        }
        await store.send(.gameTapped(.gacha)) {
            $0.game = .gacha(GachaFeature.State(cutouts: items))
        }
    }

    @MainActor
    func test_gameClose_dismisses() async {
        let items = [snap(1)]
        let store = TestStore(
            initialState: GameHubFeature.State(cutouts: items,
                                               game: .gacha(GachaFeature.State(cutouts: items)))
        ) {
            GameHubFeature()
        }
        await store.send(.game(.presented(.gacha(.close)))) {
            $0.game = nil
        }
    }
}
```
> Note: give `GameHubFeature.State` a memberwise init exposing `cutouts` and `game` for the third test.

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist generate --no-open && xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/GameHubFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: FAIL — `cannot find 'GameHubFeature'`.

- [ ] **Step 3: Write `GameHubFeature.swift`**

```swift
import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public enum GameDestination {
    case gacha(GachaFeature)
    case worldCup(WorldCupFeature)
    case cardFlip(CardFlipFeature)
    case roulette(RouletteFeature)
}

extension GameDestination.State: Equatable {}

public enum GameKind: Equatable, CaseIterable {
    case gacha, worldCup, cardFlip, roulette
    public var title: String {
        switch self {
        case .gacha: return "가챠 뽑기"
        case .worldCup: return "음식 월드컵"
        case .cardFlip: return "카드 뒤집기"
        case .roulette: return "룰렛 슬롯"
        }
    }
    public var emoji: String {
        switch self {
        case .gacha: return "🎰"
        case .worldCup: return "🏆"
        case .cardFlip: return "🃏"
        case .roulette: return "🎡"
        }
    }
    public var minimum: Int { self == .worldCup ? 2 : 1 }
}

@Reducer
public struct GameHubFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot]
        @Presents public var game: GameDestination.State?
        public init(cutouts: [CutoutSnapshot] = [], game: GameDestination.State? = nil) {
            self.cutouts = cutouts
            self.game = game
        }
    }

    public enum Action {
        case onAppear
        case cutoutsLoaded([CutoutSnapshot])
        case gameTapped(GameKind)
        case game(PresentationAction<GameDestination.Action>)
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    await send(.cutoutsLoaded(try await persistence.allCutouts()))
                }

            case let .cutoutsLoaded(cutouts):
                state.cutouts = cutouts
                return .none

            case let .gameTapped(kind):
                guard state.cutouts.count >= kind.minimum else { return .none }
                let pool = state.cutouts
                switch kind {
                case .gacha: state.game = .gacha(.init(cutouts: pool))
                case .worldCup: state.game = .worldCup(.init(cutouts: pool))
                case .cardFlip: state.game = .cardFlip(.init(cutouts: pool))
                case .roulette: state.game = .roulette(.init(cutouts: pool))
                }
                return .none

            case .game(.presented(.gacha(.close))),
                 .game(.presented(.worldCup(.close))),
                 .game(.presented(.cardFlip(.close))),
                 .game(.presented(.roulette(.close))):
                state.game = nil
                return .none

            case .game:
                return .none
            }
        }
        .ifLet(\.$game, action: \.game)
    }
}
```

- [ ] **Step 4: Write `GameHubView.swift`**

```swift
import SwiftUI
import ComposableArchitecture

public struct GameHubView: View {
    @Bindable var store: StoreOf<GameHubFeature>
    public init(store: StoreOf<GameHubFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    public var body: some View {
        ScreenScaffold(title: "오늘 뭐먹지 🎲") {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(GameKind.allCases, id: \.self) { kind in
                    let enabled = store.cutouts.count >= kind.minimum
                    Button { store.send(.gameTapped(kind)) } label: {
                        SoftCard {
                            VStack(spacing: 8) {
                                Text(kind.emoji).font(.system(size: 44))
                                Text(kind.title).font(.appSection).foregroundStyle(.appInk)
                                if !enabled {
                                    Text("누끼를 더 담아와!").font(.appCaption).foregroundStyle(.appMuted)
                                }
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                        }
                        .opacity(enabled ? 1 : 0.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { store.send(.onAppear) }
        .fullScreenCover(item: $store.scope(state: \.game, action: \.game)) { gameStore in
            switch gameStore.case {
            case let .gacha(s): GachaView(store: s)
            case let .worldCup(s): WorldCupView(store: s)
            case let .cardFlip(s): CardFlipView(store: s)
            case let .roulette(s): RouletteView(store: s)
            }
        }
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/GameHubFeatureTests -skipMacroValidation 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Game/GameHubFeature.swift Sources/FeatureKit/Game/GameHubView.swift Tests/FeatureKitTests/GameHubFeatureTests.swift
git commit -m "feat(featurekit): game hub with presented decider games

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: Root tab wire-up + full verification

**Files:**
- Modify: `Sources/FeatureKit/Root/RootFeature.swift` (add `.game` tab + `gameHub` state + scope)
- Modify: `Sources/FeatureKit/Root/FloatingTabBar.swift` (three items)
- Modify: `Sources/FeatureKit/Root/RootView.swift` (third branch)

**Interfaces:**
- Consumes: `GameHubFeature`.
- RootFeature `Tab` gains `.game`; `State` gains `var gameHub = GameHubFeature.State()`; body adds `Scope(state: \.gameHub, action: \.gameHub) { GameHubFeature() }` and an `Action.gameHub(GameHubFeature.Action)` case. Existing `RootFeatureTests` (tabChanged, cutoutTapped) stay valid.

- [ ] **Step 1: Extend `RootFeature.swift`**

Add to `enum Tab`: `case game` → `public enum Tab: Equatable { case collection, capture, game }`.
Add to `State`: `public var gameHub = GameHubFeature.State()` (after `capture`).
Add to `Action`: `case gameHub(GameHubFeature.Action)`.
Add a scope before the `Reduce` (next to the other `Scope`s):
```swift
Scope(state: \.gameHub, action: \.gameHub) { GameHubFeature() }
```
Add a no-op case in the `Reduce`'s switch (alongside `case .collection, .capture, .path:`), i.e. change it to:
```swift
case .collection, .capture, .gameHub, .path:
    return .none
```

- [ ] **Step 2: Extend `FloatingTabBar.swift`** — add the third item

In the `body`'s `HStack`, add after the capture item:
```swift
item(.game, systemImage: "die.face.5.fill", title: "뭐먹지")
```
(Leave the two existing items; the `item(_:systemImage:title:)` helper is unchanged.)

- [ ] **Step 3: Extend `RootView.swift`** — third branch

In the `switch store.tab` add:
```swift
case .game:
    GameHubView(store: store.scope(state: \.gameHub, action: \.gameHub))
```
GameHubView renders its own scaffold; wrap it in a `NavigationStack { }` only if needed for the nav-bar-hidden modifier — it is not required since games are presented via `fullScreenCover`.

- [ ] **Step 4: Build + regression + new-suite run**

Run: `tuist generate --no-open && tuist build FeatureKit`
Then the app: `xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' -skipMacroValidation 2>&1 | tail -3`
Then the full suite: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -skipMacroValidation 2>&1 | tail -6`
Expected: `Build Succeeded`, `BUILD SUCCEEDED`, `** TEST SUCCEEDED **` (existing RootFeatureTests still pass with the added tab).

- [ ] **Step 5: Simulator visual check**

Build for a booted simulator, install, launch; tap the 뭐먹지 tab, open the Gacha game, pull the lever; screenshot the hub and a game result. (Controller drives the simulator.)

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Root/RootFeature.swift Sources/FeatureKit/Root/FloatingTabBar.swift Sources/FeatureKit/Root/RootView.swift
git commit -m "feat(featurekit): add 뭐먹지 game tab to root

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review Notes (against spec)

- **Spec §3 RandomClient** → Task 1. **§3 place via mealByCutout** → used in every game's reveal effect.
- **Spec §4 GameHub + Destination enum + Presents** → Task 7; min-cutout gating in Task 7 (`gameTapped` guard) + Task 7 view (disabled cards).
- **Spec §5 four games** → Tasks 3–6, each with a TestStore test using injected `RandomClient`.
- **Spec §5 ResultCard** → Task 2, reused by all four games.
- **Spec §6 entry point (.game tab, 3-up tab bar)** → Task 8; existing RootFeature tests remain valid (only an added enum case + tab).
- **Spec §7 testing** → per-game reducer tests, RandomClient unit test, hub tests, build+screenshot in Task 8.
- **Type consistency:** every game State has `init(cutouts:)`; `GameDestination` cases wrap the four features; hub `gameTapped`/`close` handling matches the `PresentationAction` case paths; `CutoutSnapshot` fields (`id`,`fileName`,`label`) used consistently.

## Notes for the implementer

- `-destination 'id=…'` needs a booted sim UDID (`3B1E5795-617D-4955-8048-0CC8AD03BE95` if booted; else `xcrun simctl list devices booted`). Always pass `-skipMacroValidation` to xcodebuild (Point-Free macros).
- TCA 1.26 enum reducers: `@Reducer enum GameDestination { … }` synthesizes `GameDestination.State`/`.Action` enums; `@Presents var game: GameDestination.State?` + `.ifLet(\.$game, action: \.game)`. In the view, `$store.scope(state: \.game, action: \.game)` yields an optional store whose `.case` switches the four games. If a macro/API spelling differs in the resolved version, adapt to it — the behavior and the store bindings are the contract.
- If `CutoutSnapshot` is unresolved in a view file, add `import Models`.
- Do not modify Models, ClientKit persistence, or the Capture/Collection/MealDetail reducers/tests.
