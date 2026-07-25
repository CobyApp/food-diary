# 음식 도감 (Achievements) — Design Spec

- **Date:** 2026-07-25
- **Scope:** An achievements/milestone "도감" sheet reached from a 🏆 button on
  the Collection screen. Badges unlock from existing stats (cutout count, distinct
  restaurants, meal count). Roadmap feature 3 of 8.
- **Status:** Approved (brainstorming), ready for implementation plan.

## 1. Concept

A collectible "도감" of achievement badges the user unlocks by using the app —
"첫 누끼", "누끼 10개", "맛집 5곳", etc. Each badge shows locked/unlocked state
and progress. No cuisine/category data is required — everything derives from
counts the app already stores.

## 2. Global Constraints

- Additive: a new FeatureKit `Achievements/` feature, presented as a sheet from
  `CollectionFeature` (which gains a presented child + a button action).
  `CollectionFeatureTests` existing assertions must still pass (only new cases
  added). No Models/other-client changes.
- Pastel DesignSystem; light mode; SF Rounded; Korean UI strings.
- iOS 18, Swift 6, TCA 1.26. Always `-skipMacroValidation`; never `tuist install`
  / edit `Project.swift`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## 3. Data & Stats

- `AchievementsFeature` loads on appear:
  - `cutoutCount = (try persistence.allCutouts()).count`
  - `meals = try persistence.allMeals()` → `mealCount = meals.count`,
    `placeCount = Set(meals.compactMap { $0.place?.id }).count` (distinct places).
- No new persistence method needed (`allCutouts` + `allMeals` exist).

## 4. Achievement Model

```swift
public struct Achievement: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let emoji: String
    public let target: Int
    public let current: Int
    public var unlocked: Bool { current >= target }
    public var progress: Double { target == 0 ? 1 : min(1, Double(current) / Double(target)) }
}
```

- A static catalog maps `(title, emoji, metric, target)` to an `Achievement` given
  the three stats. `enum Metric { case cutouts, places, meals }`.
- Catalog (v1):
  - 첫 누끼 🍽 — cutouts ≥ 1
  - 누끼 10개 🥉 — cutouts ≥ 10
  - 누끼 50개 🥈 — cutouts ≥ 50
  - 누끼 100개 🥇 — cutouts ≥ 100
  - 첫 맛집 📍 — places ≥ 1
  - 맛집 5곳 🗺️ — places ≥ 5
  - 맛집 10곳 🌏 — places ≥ 10
  - 기록 30개 📔 — meals ≥ 30

## 5. Architecture

- **`AchievementsFeature`** (`@Reducer`): `@ObservableState struct State { var cutoutCount = 0; var mealCount = 0; var placeCount = 0; var achievements: [Achievement] }` (achievements computed from the three counts via the catalog), `enum Action { case onAppear; case statsLoaded(cutouts: Int, meals: Int, places: Int); case close }`.
- **`AchievementsView`**: a pastel grid of badge cards — unlocked = colorful
  `StickerTile`-ish card with the emoji + title + "달성!"; locked = greyed emoji +
  title + a small progress bar ("current/target"). A "닫기" control.
- **Entry:** `CollectionFeature` gains `@Presents var achievements:
  AchievementsFeature.State?` + `Action.achievementsButtonTapped` (sets it) +
  `Action.achievements(PresentationAction<AchievementsFeature.Action>)` (on
  `.close` → nil) + `.ifLet`. `CollectionView` adds a 🏆 button (top-trailing
  overlay) sending `achievementsButtonTapped`, and a `.sheet(item:)` hosting
  `AchievementsView`.

## 6. Testing

- `AchievementsFeature`: `onAppear` loads stats (stubbed `allCutouts`/`allMeals`);
  `statsLoaded` produces the catalog with correct `unlocked` flags for given
  counts (e.g. 10 cutouts unlocks 첫 누끼 + 누끼 10개 but not 50).
- `CollectionFeature`: `achievementsButtonTapped` presents; `.achievements(.presented(.close))` dismisses. (Existing onAppear test unaffected.)
- View verified by build + a simulator screenshot (open the sheet from Collection).

## 7. Out of Scope

Streak-based badges (feature 5), cuisine categories, share of a badge, badge
detail pages, notifications on unlock.
