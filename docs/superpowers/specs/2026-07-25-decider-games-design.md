# "오늘 뭐먹지?" Decider Game Hub — Design Spec

- **Date:** 2026-07-25
- **Scope:** A new "🎲 뭐먹지" tab with a game hub and **four decider mini-games**
  (Gacha, Food World Cup, Card Flip, Roulette/Slot) that pick a meal from the
  user's collected food cutouts. First feature of the "all features" roadmap.
- **Status:** Approved (brainstorming), ready for implementation plan.

## 1. Concept

Turn the collected food cutouts into a playful "what should I eat today?"
decider. The user opens the 뭐먹지 tab, picks a game, plays it, and the game
lands on one cutout → **"오늘은 여기! 🍜 [식당명]"**. Fun, fast, re-rollable.

## 2. Global Constraints

- View + one new client only. Reuses existing `PersistenceClient.allCutouts` and
  `.mealByCutout`; **does not change** existing reducers/models/other clients or
  their tests. Existing suite must stay green.
- Pastel design system (Task-existing `DesignSystem/`) reused throughout; light
  mode only. SF Rounded. Korean UI strings.
- Games live in `Sources/FeatureKit/Game/`. New `RandomClient` in `ClientKit`.
- No new Tuist target. iOS 18, Swift 6, TCA 1.26.
- Randomness is injected via `RandomClient` so every game reducer is
  deterministically testable with `TestStore`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## 3. Data & Client

- Source pool: `[CutoutSnapshot]` from `persistence.allCutouts()` (newest-first
  already). `CutoutSnapshot` has `id`, `fileName`, `createdAt`, `label`.
- Result place name: `persistence.mealByCutout(cutoutID)` → `MealSnapshot?` →
  `.place?.name` (async, one call when a result is revealed).
- **`RandomClient`** (`ClientKit`, `@DependencyClient`):
  - `shuffled: @Sendable ([CutoutSnapshot]) -> [CutoutSnapshot]`
  - `pick: @Sendable ([CutoutSnapshot]) -> CutoutSnapshot?`
  - `liveValue`: `shuffled` = `$0.shuffled()`, `pick` = `$0.randomElement()`.
  - `testValue`/`previewValue`: deterministic (identity order; `pick` = first).
  - `DependencyValues.random`.

## 4. Architecture

- **`GameHubFeature`** (`@Reducer`): loads `allCutouts` on appear; shows four
  game cards. Presents the chosen game full-screen via a Destination enum:
  - `@Reducer enum GameDestination { case gacha(GachaFeature); case worldCup(WorldCupFeature); case cardFlip(CardFlipFeature); case roulette(RouletteFeature) }`
  - `@Presents var game: GameDestination.State?`; tapping a card sets it with the
    loaded `cutouts`. Each game exposes a `close` action → hub sets `game = nil`.
- Each game reducer holds the `cutouts` pool (passed in at presentation), the
  in-progress state, and the revealed result + resolved place name. **No
  cross-feature navigation in v1** (no push to MealDetail) — result offers
  **[다시 뽑기]** and **[닫기]** only. (MealDetail nav is a future nicety.)
- Minimum-cutout handling: each game needs a minimum (Gacha/CardFlip/Roulette ≥
  1, WorldCup ≥ 2). The hub disables a game card and shows a hint
  ("누끼를 더 담아와!") when the pool is too small.

## 5. The Four Games

Each game's **result state** is `result: CutoutSnapshot?` + `resultPlace: String?`
(loaded via `mealByCutout`), rendered by a shared `ResultCard` view (big
`StickerTile` of the cutout + "오늘은 여기! 🍜 [place ?? label]" + 다시/닫기).

1. **🎰 Gacha** — `GachaFeature`: `pullLever` → `random.pick(cutouts)` sets
   `result`, `isSpinning = true`, and fires a `mealByCutout` effect → `placeLoaded`.
   View: capsule machine, lever tap, spring "capsule pops + opens" animation
   revealing the cutout.
2. **🏆 Food World Cup** — `WorldCupFeature`: on `start`, bracket size = largest
   power of two ≤ `cutouts.count`, min 2, max 16; `currentRound =
   random.shuffled(cutouts).prefix(size)`. Show one pair at a time; `pick(winner)`
   appends the winner to `nextRound` and advances; when a round finishes,
   `currentRound = nextRound`; when one remains → champion (result). View: two big
   cutout cards side by side + round label ("8강", "결승").
3. **🃏 Card Flip** — `CardFlipFeature`: on `start`, `cards =
   random.shuffled(cutouts).prefix(6)` laid face-down. `flip(index)` reveals
   `cards[index]` as the pick (result). View: face-down pastel card grid → flip
   animation reveals the chosen cutout.
4. **🎡 Roulette/Slot** — `RouletteFeature`: `spin` → `random.pick(cutouts)` sets
   result, `isSpinning = true`, place effect. View: a vertical slot reel of
   cutouts scrolling and easing to a stop on the result.

## 6. Entry Point

- `RootFeature.Tab` gains `.game`. `FloatingTabBar` becomes three items:
  `컬렉션 / 담기 / 🎲 뭐먹지`. `RootView` switches a third branch to
  `GameHubView` (its own `NavigationStack` not required — games are presented).

## 7. Testing

- **Reducers (TestStore + injected `RandomClient` + stubbed `persistence`):**
  - Gacha: `pullLever` sets the injected pick as `result`; `placeLoaded` sets place.
  - WorldCup: from a known shuffled pool, a sequence of `pick` advances rounds
    and yields the expected champion.
  - CardFlip: `start` lays the injected order; `flip(index)` selects `cards[index]`.
  - Roulette: `spin` sets the injected pick as `result`.
  - GameHub: `onAppear` loads cutouts; tapping a card presents the right
    destination with the pool; a game's `close` clears `game`.
  - `RandomClient` gets a small unit test (`shuffled` preserves multiset; `pick`
    returns a member) in `ClientKitTests`.
- Views verified by building + a simulator screenshot of the hub and one game.
- Animations are view-only; reducers use injected randomness (no `Clock`
  dependency needed — spin visuals are pure SwiftUI animation on a state flag).

## 8. Out of Scope (this feature)

Navigation from a result to MealDetail; logging the pick as a new meal; sharing
the result; sound/haptics polish (a light haptic is fine if trivial). Later
roadmap items (map, 도감, recap, streak, decoration, profile, widget) are
separate features.
