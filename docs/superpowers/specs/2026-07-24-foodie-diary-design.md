# Foodie Diary — Design Spec

- **Date:** 2026-07-24
- **Bundle ID:** `com.coby.food.dairy`
- **Status:** Approved (brainstorming), ready for implementation plan

## 1. Concept

A personal "foodie diary". When you eat, you take a photo of your food. The app:

1. **Auto-extracts the food as a cutout** (transparent-background PNG) from the
   photo using on-device Vision. Multiple cutouts per single photo/meal are
   supported.
2. **Suggests nearby restaurants** from the photo's GPS location so you can tag
   where you ate (or enter it manually).
3. **Collects the cutouts on a "collection wall"** (sticker-book feel) as the
   home screen, each linking back to the meal it belongs to.

The emotional core is *collecting* food cutouts — a foodie sticker book — not a
timeline or a map (those are deferred to v2).

## 2. Tech Stack & Target

- **Tuist 4** — project generation & management (no committed `.xcodeproj`)
- **TCA 1.x** — The Composable Architecture (`@Reducer`, `@ObservableState`,
  `@Presents`, `StackState` for navigation)
- **SwiftUI** — all UI
- **SwiftData** — local persistence
- **Vision** — food cutout (`VNGenerateForegroundInstanceMaskRequest`, on-device)
- **CoreLocation / ImageIO** — GPS extraction from photo EXIF
- **Fastlane** — `test` / `build` / `beta` lanes
- **Minimum deployment target: iOS 18.0**
  - Rationale: mature SwiftData, stable Vision subject lifting, modern TCA
    observation.
- **Swift 6** language mode where practical (strict concurrency).

## 3. Module Structure (Tuist targets → isolated build/test)

```
FoodDiary          (App)     — entry point, RootStore, tab navigation, DI wiring
 ├─ FeatureKit     (framework) — TCA reducers + SwiftUI views
 │                              (Collection / MealDetail / Capture / PlacePicker)
 ├─ ClientKit      (framework) — TCA Dependency clients (4)
 └─ Models         (framework) — SwiftData @Model types + domain value types
+ FeatureKitTests, ClientKitTests, ModelsTests
```

Dependency direction: `App → FeatureKit → ClientKit → Models`.
`Models` has no internal deps. `ClientKit` depends only on `Models`.

## 4. Data Model (SwiftData; images stored on disk as PNG)

- **`Meal`** (`@Model`)
  - `id: UUID`
  - `eatenAt: Date`
  - `place: PlaceInfo?` (embedded value: `name`, `address`, `latitude`,
    `longitude`, `googlePlaceId?`) — stored as a Codable attribute
  - `memo: String`
  - `rating: Int?` (0–5, optional)
  - `cutouts: [FoodCutout]` (one-to-many relationship, cascade delete)
- **`FoodCutout`** (`@Model`)
  - `id: UUID`
  - `fileName: String` — transparent PNG stored under
    `Documents/cutouts/<fileName>`; DB stores only the file name
  - `createdAt: Date`
  - `label: String?`
  - inverse relationship → `meal`
- **`PlaceInfo`** — plain `Codable` value type (not a `@Model`), embedded on `Meal`.

**Image storage policy:** original source photos are **not** persisted; only the
extracted cutout PNGs are kept on disk. (Confirmed in brainstorming.)

## 5. Core Flow (Capture feature)

```
Take / pick photo
 → PhotoLocationClient: extract GPS coordinate from EXIF (may be nil)
 → FoodCutoutClient: Vision extracts N food cutouts → [CutoutResult]
      → user multi-selects which cutouts to keep
 → PlaceSearchClient.nearby(coordinate): nearby restaurant list
      → user picks one, or enters place manually, or skips
 → PersistenceClient.save(Meal + selected cutouts)
 → new cutouts appear on the Collection wall (home)
```

Fallbacks: no GPS → skip nearby search, allow manual place entry. No cutout
detected → allow saving the whole image as a single cutout (or retake).

## 6. Dependency Clients (all `@DependencyClient`, with mock/preview values)

| Client | Interface (async) | Live impl | Status now |
|---|---|---|---|
| `FoodCutoutClient` | `extract(UIImage) throws -> [Cutout]` | Vision on-device | real |
| `PhotoLocationClient` | `coordinate(from: Data) -> Coordinate?` | ImageIO EXIF | real |
| `PlaceSearchClient` | `nearby(Coordinate) throws -> [PlaceInfo]` | Google Places (key via `.xcconfig`) | **mock** |
| `PersistenceClient` | Meal/Cutout CRUD | SwiftData `ModelActor` | real |

- `PlaceSearchClient` is abstracted so the Google Places live implementation can
  be dropped in later without touching features. During development it returns
  deterministic mock/preview data. The API key is injected via a git-ignored
  `.xcconfig`; no key is committed.
- `PersistenceClient` wraps a SwiftData `ModelActor` and exposes async CRUD
  returning `Sendable` value-type snapshots (DTOs), so it composes cleanly with
  TCA + strict concurrency (features hold value-type state, not live
  `@Model` objects).

## 7. Home = Collection Wall

- A grid of every saved `FoodCutout` rendered on transparent background
  (sticker-book feel). Tapping a cutout navigates to its parent `Meal` detail.
- Tab bar: **Collection (home)** / **Capture (+)**. Timeline and Map tabs are
  placeholders reserved for v2.

## 8. Testing (TDD)

- **Reducers:** TCA `TestStore` + mock clients to verify the capture flow, save,
  and collection loading. Exhaustive state assertions.
- **Clients:**
  - `FoodCutoutClient` — run against a bundled test food image, assert ≥1 cutout
    returned with non-empty PNG data.
  - `PhotoLocationClient` — run against a bundled image with known GPS EXIF,
    assert the parsed coordinate matches.
  - `PersistenceClient` — in-memory `ModelContainer`, assert CRUD round-trips.

## 9. Tooling & Repo Hygiene

- **Fastlane** lanes scaffolded: `test`, `build`, `beta` (TestFlight). Fastlane
  is not yet installed on the machine → `brew install fastlane` will be needed
  before running lanes.
- **Tuist**: `Project.swift` + `Tuist.swift`/config; generated `.xcodeproj` is
  git-ignored.
- **`.gitignore`**: Xcode/Tuist/SPM artifacts, `.xcconfig` secrets, `Derived/`.
- **`.xcconfig`**: `Secrets.xcconfig` (git-ignored) for the Google Places key;
  a committed `Secrets.example.xcconfig` documents the expected keys.

## 10. Out of Scope for v1 (deferred to v2+)

- Timeline view, Map view
- Cloud sync / accounts / multi-device
- Real Google Places integration (interface only in v1)
- Sharing / export, social features
- Storing original photos

## 11. Open Risks / Notes

- `VNGenerateForegroundInstanceMaskRequest` quality varies by photo; provide a
  manual "keep whole image" fallback.
- SwiftData + TCA concurrency handled via a `ModelActor`-backed client returning
  DTOs (avoid passing `@Model` across actor boundaries).
- Google Places billing/key + optional backend proxy are a future concern; v1
  ships the swappable interface only.
