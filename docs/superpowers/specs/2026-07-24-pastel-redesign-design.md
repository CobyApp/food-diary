# Pastel "Soft Dairy" Redesign — Design Spec (Phase 1)

- **Date:** 2026-07-24
- **Scope:** Phase 1 of a 4-phase renewal. This phase = a **Newtro pastel design
  system + a view-layer reskin** of the three existing screens (Collection /
  Capture / MealDetail). No new features, no reducer/data changes.
- **Later phases (out of scope here):** ② cutout decoration (stickers/frames/
  backgrounds), ③ profile/onboarding, ④ shareable card export. Each gets its own
  spec → plan.
- **Status:** Approved (brainstorming), ready for implementation plan.

## 1. Direction

"Soft Pastel Dairy" — the NewJeans *Ditto/Cookie* mood: milky off-white canvas,
baby-blue / baby-pink / butter pastels, rounded-everything, soft shadows, airy
whitespace, tiny star/dot doodles. **No mascot** — identity carried by
typography, color, and doodle motifs. Cute, dreamy, Gen-Z newtro.

## 2. Global Constraints

- **View-layer only.** TCA reducers, `ClientKit`, `Models`, and all tests stay
  unchanged. This is a reskin of the SwiftUI views + a new design-system layer.
  Existing FeatureKit/ClientKit/Models tests must stay green.
- **Light mode only** for v1 (pastels degrade in dark; `.preferredColorScheme(.light)`
  at the app root). Dark mode is deferred.
- **Typography: SF Rounded** (`.system(..., design: .rounded)`) — native, no
  bundled font, no licensing. Weights: heavy/black titles, semibold sections,
  regular body.
- **No new dependencies, no new Tuist target.** The design system lives inside
  FeatureKit at `Sources/FeatureKit/DesignSystem/`.
- Korean UI strings stay Korean. Source comments English only.
- Min iOS 18, Swift 6, TCA 1.26.

## 3. Design Tokens (`Sources/FeatureKit/DesignSystem/`)

### 3.1 Color — `AppColor.swift` (SwiftUI `Color` extension)
| Token | Hex | Role |
|---|---|---|
| `milk` | `#FCF8F5` | app background canvas |
| `card` | `#FFFFFF` | cards, sticker tiles, tab bar |
| `blue` | `#8FBEEA` | primary (buttons, active tab, accents) |
| `blueInk` | `#5385C4` | primary text-on-light / labels |
| `pink` | `#F7C2D6` | secondary accent / chips |
| `pinkInk` | `#C67191` | pink text-on-light |
| `butter` | `#FBE6A6` | highlight / rating stars fill |
| `butterInk` | `#B99329` | butter text-on-light |
| `ink` | `#4B4A57` | primary text (soft charcoal, never pure black) |
| `muted` | `#A6A2B0` | secondary text, placeholders |
| Tile tints | `#FDEBF2` (pink) `#EAF3FC` (blue) `#FCF3D6` (butter) | rotating sticker-tile backgrounds |

### 3.2 Typography — `AppFont.swift`
- `display` = `.system(size: 25, weight: .black, design: .rounded)` (screen titles)
- `title` = `.system(size: 20, weight: .heavy, design: .rounded)`
- `section` = `.system(size: 15, weight: .semibold, design: .rounded)`
- `body` = `.system(size: 15, weight: .regular, design: .rounded)`
- `caption` = `.system(size: 12, weight: .semibold, design: .rounded)`
- Titles use tight tracking (`-0.6`).

### 3.3 Shape / Elevation — `AppStyle.swift`
- Corner radii: card `20`, sticker tile `15`, chip/pill `999` (full), drop-zone `16`.
- Soft shadow: `color .purple-ish rgba(150,120,180,0.14)`, `radius 12`, `y 5`.
  (One shared `.softShadow()` `ViewModifier`.)
- Spacing scale: 8 / 12 / 16 / 22.

## 4. Reusable Components (`Sources/FeatureKit/DesignSystem/Components/`)

Each is a small, focused SwiftUI `View`/modifier consumed by the three screens.

- **`StickerTile`** — white/pastel-tinted rounded tile + soft shadow, holds a
  `CutoutImage` (or emoji placeholder). Tint rotates by index. Used in the
  Collection grid, MealDetail grid, and (checkmarked) as Capture candidates.
- **`PillButton`** — full-radius baby-blue filled button, white heavy label,
  soft blue shadow; disabled state = muted fill. (Capture "저장", etc.)
- **`PastelChip`** — full-radius pastel-filled label chip with a leading glyph;
  variants `.blue` / `.pink` / `.butter`. (place, date, memo, rating labels.)
- **`StarRating`** — butter-filled ★ row (read + edit variants; edit taps set 0–5).
- **`DropZoneCard`** — dashed baby-blue border, tinted fill, centered
  camera+label; wraps the `PhotosPicker`.
- **`SoftCard`** — white rounded container + soft shadow (info panels).
- **`EmptyState`** — centered doodle glyph + heavy title + muted subtitle.
- **`ScreenScaffold`** — milk background + large rounded title (with a `✦` doodle)
  + content slot; standardizes each screen's header/background.
- **`FloatingTabBar` styling** — the `RootView` TabView is restyled to a floating
  white rounded pill; active item = `blueInk`. (Custom tab bar appearance, or a
  bespoke bottom bar if `TabView` styling is insufficient — implementer's call,
  behavior unchanged: two tabs 컬렉션 / 담기.)

## 5. Per-Screen Redesign (behavior identical; only presentation changes)

### 5.1 Collection (home) — `CollectionView`
- `ScreenScaffold` title **"컬렉션 ✦"** on milk.
- Adaptive grid of `StickerTile`s (rotating tints) instead of plain cells; tap →
  same `cutoutTapped` navigation.
- Empty state → `EmptyState`: fork/knife doodle, "아직 누끼가 없어요", subtitle.
- Content sits above the floating tab bar.

### 5.2 Capture (담기) — `CaptureView`
- `ScreenScaffold` title **"한 끼 담기"**.
- Photo entry → `DropZoneCard` wrapping the existing `PhotosPicker`.
- Processing → pastel `ProgressView` ("음식 누끼 따는 중…").
- Candidates → horizontal row of `StickerTile` with a selectable check badge
  (reuse `toggleCandidate`).
- Meal info → `SoftCard` with rows: 식당 (`PastelChip.blue`, opens place picker),
  메모 (`TextField`), 별점 (`StarRating` edit).
- Save → `PillButton` "다이어리에 저장 ♡" (disabled when no candidate selected).
- Place-picker sheet (`PlacePickerView`) restyled with `PastelChip` list rows +
  `PillButton`.

### 5.3 MealDetail — `MealDetailView`
- Hero: place name (or "한 끼 기록") in `display` font.
- `PastelChip.blue` date + `StarRating` (read) row.
- Memo in a `SoftCard`.
- `StickerTile` grid of the meal's cutouts.
- Delete stays behind the existing confirmation dialog; restyle the toolbar
  button tint to `pinkInk`.

## 6. Architecture Notes

- New folder `Sources/FeatureKit/DesignSystem/` (tokens) +
  `.../DesignSystem/Components/` (reusable views). No new module/target — avoids
  the static-framework linkage churn documented in the prior plan.
- Views consume tokens/components; **reducers and state are untouched**, so the
  reskin cannot regress logic. `CutoutImage` (async disk load) is reused as-is
  inside `StickerTile`.
- App root sets `.preferredColorScheme(.light)`.

## 7. Testing / Verification

- No reducer changes → existing unit tests remain the correctness gate and must
  stay green (`tuist test` / `xcodebuild test -scheme FoodDiary`).
- Views verified by **building + launching in the simulator** and capturing
  screenshots of all three screens (empty + populated Collection, Capture with
  candidates, MealDetail). Vision cutouts don't run on the simulator, so
  populate via seeded/preview data or emoji placeholders for the visual check.
- Optional: SwiftUI `#Preview`s for each reusable component and screen.

## 8. Out of Scope (this phase)

Cutout decoration, profile/onboarding, share-card export, dark mode, timeline/map,
any change to persistence, clients, or reducers.
