# 내 맛집 지도 (Food Map) — Design Spec

- **Date:** 2026-07-25
- **Scope:** A new "🗺️ 지도" (4th) tab showing the user's eaten restaurants as
  pastel pins on a MapKit map. Roadmap feature 2 of 8.
- **Status:** Approved (brainstorming), ready for implementation plan.

## 1. Concept

Plot every logged meal that has a place coordinate onto a map as a pastel pin
carrying its food-cutout thumbnail. Tapping a pin shows a bottom card with the
restaurant name, date, and that meal's cutouts. A personal "맛집 지도".

## 2. Global Constraints

- Additive: adds `PersistenceClient.allMeals` (ClientKit) + a new FeatureKit
  `Map/` feature + a `.map` tab on `RootFeature`. Does not change Models, other
  clients, or the Capture/Collection/MealDetail/Game reducers or their tests.
  Existing suite stays green.
- Pastel DesignSystem reused; light mode; SF Rounded; Korean UI strings.
- iOS 18, Swift 6, TCA 1.26. No new Tuist target. Uses MapKit (already linked).
- Always pass `-skipMacroValidation` to xcodebuild; never `tuist install` or edit
  `Project.swift`.

## 3. Data

- **`PersistenceClient.allMeals: @Sendable () async throws -> [MealSnapshot]`**
  (new). Actor method fetches all `Meal` (newest-first by `eatenAt`) → snapshots.
  Live/preview/`allMeals` accessor added; deterministic in-memory test.
- `MealSnapshot` already carries `place: PlaceInfo?` (with `coordinate:
  Coordinate?`), `eatenAt`, and `cutouts`. The map uses only meals where
  `place?.coordinate != nil`.

## 4. Architecture

- **`FoodMapFeature`** (`@Reducer`):
  - `@ObservableState struct State: Equatable { var meals: [MealSnapshot] = []; var selectedMealID: UUID? }`
    with a computed `var pins: [MealSnapshot]` = `meals.filter { $0.place?.coordinate != nil }`
    and `var selectedMeal: MealSnapshot?`.
  - `enum Action { case onAppear; case mealsLoaded([MealSnapshot]); case pinTapped(UUID); case dismissCard }`.
  - `onAppear` → `persistence.allMeals()` → `mealsLoaded`. `pinTapped` sets
    `selectedMealID`; `dismissCard` clears it.
- **`FoodMapView`**: SwiftUI `Map` (`MapCameraPosition.automatic` to frame all
  pins) with an `Annotation` per pin — a pastel round pin holding the meal's first
  cutout thumbnail (`CutoutImage`) with a soft shadow; tap → `pinTapped`. When a
  meal is selected, a bottom `SoftCard` overlay shows a `PastelChip` place name +
  date + a horizontal row of the meal's cutout thumbnails, with a close control.
  Empty state (no pins) → `EmptyState` ("아직 지도에 찍힌 곳이 없어요").
- **Entry:** `RootFeature.Tab` gains `.map`; `FloatingTabBar` becomes four items
  (컬렉션 / 담기 / 뭐먹지 / 지도); `RootView` adds a `.map` branch rendering
  `FoodMapView`. Existing `RootFeatureTests` stay valid (added enum case only).

## 5. Testing

- `PersistenceClient.allMeals`: in-memory container, save two meals, assert
  `allMeals()` returns both (newest-first).
- `FoodMapFeature`: `onAppear` loads meals; `pins` filters out meals without a
  coordinate; `pinTapped` sets `selectedMealID`; `dismissCard` clears it (TestStore).
- `FoodMapView` verified by building + a simulator screenshot (map renders; with
  no data, the empty state shows — seeding real pins needs device data, so the
  screenshot verifies the map/empty-state chrome).

## 6. Out of Scope

Navigation from a pin to MealDetail; clustering; search; filtering by
cuisine/date; directions. (Later.)
