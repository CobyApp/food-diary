# 컬렉션 월 v2 (Flip + Parallax) — Design Spec

- **Date:** 2026-07-25
- **Scope:** Replace the pushed meal-detail with an in-place **flip** on each
  collection sticker (front = cutout, back = 가게/날짜/한줄평 + delete), and add a
  subtle **gyro parallax** to the sticker wall. Integrates with the current
  (heavily-evolved) `CollectionFeature`/`CollectionView`/`RootFeature`.
- **Status:** Approved (brainstorming), ready for implementation plan.

## 1. Concept & constraints

Meals hold only 1–2 cutouts, so a full pushed detail screen is overkill. Tapping
a sticker flips it in place to reveal its restaurant, date, and one-line memo
(with a delete). The wall also reacts to device tilt (parallax) so it feels alive.

**Honest:** gyro parallax has no sensor in the simulator — it renders flat there
and is felt only on device (like Vision/GameKit). The flip is fully testable.

## 2. Global Constraints

- Surgical integration with existing files. Do NOT change the multi-select
  delete, streak, profile, achievements, recap, or widget flows. Keep
  `MealDetailFeature`/`View` (dormant) so their tests stay green.
- Pastel/kitsch DesignSystem reused; light mode; SF Rounded; Korean UI + `L10n`.
- iOS 18, Swift 6, TCA 1.26. Always `-skipMacroValidation`; never `tuist install`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## 3. Flip (TCA)

- **`CutoutMealInfo`** (value): `placeName: String`, `dateText: String`, `memo: String`.
- **`CollectionFeature.State`** gains `var flippedCutoutID: UUID?` and
  `var cutoutMealInfo: [UUID: CutoutMealInfo] = [:]`.
- **`onAppear`** additionally loads `persistence.allMeals()` and builds the
  `cutoutMealInfo` lookup (each cutout id → its meal's place name, formatted date,
  memo), delivered via a new `Action.mealInfoLoaded([UUID: CutoutMealInfo])`.
- **`cutoutTapped(id)`** (currently a no-op the parent intercepts) becomes:
  toggle `flippedCutoutID` (tap the flipped one again → unflip). This is the only
  behavior change to an existing action; the editing path (`selectionToggled`) is
  untouched.
- **Delete from the back** reuses the existing `deleteCutoutsConfirmed([id])`.
- **`RootFeature`**: remove ONLY the `case .collection(.cutoutTapped(...))` →
  `pushDetail` interception (so the tap flips instead of pushing). `path`,
  `pushDetail`, the `MealDetailFeature` scope, and the `.path` handlers remain
  (dormant) to avoid touching the widget/delete flow.

## 4. Flip (View)

- In `CollectionView`, the grid cell becomes a two-faced flip: the existing
  `StickerTile { CutoutImage }` front and a new back card (pastel `SoftCard`-style)
  showing `cutoutMealInfo[id]` — 가게명 (or "기록"), date, "한줄평", and a small
  삭제 button — using `rotationEffect3D`/`rotation3DEffect` around Y, driven by
  `store.flippedCutoutID == cutout.id`. Editing mode (checkmarks) and the
  decoration/label overlays stay on the front and are unchanged.
- The context-menu "기록 보기" keeps sending `cutoutTapped` (now flips).

## 5. Parallax (view-only, CoreMotion)

- **`ParallaxMotion`** (`@Observable`, new file): owns a `CMMotionManager`, starts
  device-motion updates on `start()`, exposes a normalized `tilt: (x: Double, y: Double)`
  (roll/pitch clamped to −1…1). No sensor (simulator) → stays `(0,0)`.
- A **`.parallax(_ strength:)`** `ViewModifier` offsets a view by
  `tilt * strength` and shifts its shadow slightly. `CollectionView` owns a
  `@State private var motion = ParallaxMotion()`, `.task { motion.start() }`, and
  applies `.parallax()` to the sticker tiles (small strength, e.g. 6–10 pt) so the
  wall drifts gently with tilt. No reducer involvement (high-frequency, view-only).

## 6. Testing

- `CollectionFeature`: `cutoutTapped` toggles `flippedCutoutID` (tap again →
  nil); `onAppear` → `mealInfoLoaded` populates `cutoutMealInfo` (stubbed
  `allMeals`). Existing tests (onAppear cutouts load, delete, etc.) keep passing.
- `RootFeature`: the old "cutoutTapped → pushDetail" test is replaced — assert that
  `.collection(.cutoutTapped)` no longer produces `.pushDetail` (flip handled in the
  child). `tabChanged` test unchanged.
- Flip view + parallax: build-verified; parallax felt on device only.

## 7. Out of Scope

Deleting `MealDetailFeature` (kept dormant); flip animations beyond a Y-axis flip;
motion-driven physics; per-sticker independent parallax depth layers.
