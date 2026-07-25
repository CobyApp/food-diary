# 주간 리캡 카드 + 공유 (Weekly Recap) — Design Spec

- **Date:** 2026-07-25
- **Scope:** A shareable "이번 주 한 끼" recap card (collage of the past 7 days'
  cutouts) opened from a 🎞️ button on the Collection screen, exported via the iOS
  share sheet. Roadmap feature 4 of 8.
- **Status:** Approved (brainstorming), ready for implementation plan.

## 1. Concept

Auto-generate a cute pastel card summarizing the week's meals — a collage of the
food cutouts from the last 7 days, the meal count, and the date range — that the
user can share to Instagram Stories / anywhere via the system share sheet.

## 2. Global Constraints

- Additive: a new FeatureKit `Recap/` feature, presented as a sheet from
  `CollectionFeature` (a second `@Presents` child + button action, alongside the
  existing achievements sheet). Existing `CollectionFeatureTests` assertions must
  still pass. No Models/other-client changes.
- Pastel DesignSystem; light mode; SF Rounded; Korean UI strings.
- iOS 18, Swift 6, TCA 1.26. Always `-skipMacroValidation`; never `tuist install`
  / edit `Project.swift`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## 3. Architecture

- **`RecapFeature`** (`@Reducer`) — the testable filtering logic (no images):
  - `@ObservableState struct State: Equatable { var weekCutouts: [CutoutSnapshot] = []; var mealCount = 0; var rangeText = "" }`.
  - `enum Action: Equatable { case onAppear; case loaded(cutouts: [CutoutSnapshot], mealCount: Int, rangeText: String); case close }`.
  - `@Dependency(\.date.now)` + `@Dependency(\.persistence)`. `onAppear` loads
    `allMeals()`, filters to `eatenAt >= now - 7 days`, sets `weekCutouts =
    week.flatMap(\.cutouts)`, `mealCount = week.count`, and a `rangeText` like
    "7.18~7.25" (`weekAgo`…`now` via `.formatted(.dateTime.month().day())`).
- **`RecapCardView`** — the fixed-width (≈320pt) shareable design: milk
  background, "이번 주 한 끼 🍽" title, "N끼 · 범위" subtitle, a collage grid of
  cutout thumbnails (rendered from pre-loaded `Data` via `CutoutImage(data:)`), and
  a small "Foodie Diary ✦" footer.
- **`RecapView`** — hosts the card: on appear it loads each `weekCutouts`
  fileName's PNG `Data` off the main thread into `@State [Data]` (via
  `ImageStore.disk(directory: .cutoutsDirectory).load`), shows `RecapCardView`, and
  a **`ShareLink`** whose item is the card rendered to an `Image` via
  `ImageRenderer` (synchronous — hence the pre-loaded `Data`, so the collage isn't
  blank in the export). Empty week → `EmptyState` ("이번 주 기록이 없어요").
- **Entry:** `CollectionFeature` gains `@Presents var recap: RecapFeature.State?`
  + `Action.recapButtonTapped` + `Action.recap(PresentationAction<...>)` +
  `.ifLet`. `CollectionView` adds a second header button (🎞️, left of the existing
  🏆) sending `recapButtonTapped`, and a `.sheet(item:)` hosting `RecapView`.

## 4. Testing

- `RecapFeature`: with `$0.date = .constant(fixedNow)` and a stubbed `allMeals`
  containing a recent meal (2 cutouts) and an old meal (30 days ago), `onAppear`
  → `loaded` sets `weekCutouts` to the recent meal's cutouts and `mealCount = 1`
  (TestStore, non-exhaustive so `rangeText` isn't asserted verbatim).
- `CollectionFeature`: `recapButtonTapped` presents; `recap(.presented(.close))`
  dismisses (both existing achievements + onAppear tests still pass).
- `RecapCardView`/`RecapView` verified by building + a simulator screenshot
  (opens the sheet; empty-week state shows since the sim has no recent meals).

## 5. Out of Scope

Choosing a template/theme; multi-week/monthly recaps; direct-to-Instagram
posting (share sheet only); watermark customization.
