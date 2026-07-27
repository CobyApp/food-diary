# 게임 리디자인 (Card Flip Simplify · Roulette Wheel · Gacha Dial) — Design Spec

- **Date:** 2026-07-26
- **Scope:** Three targeted redesigns from user feedback: revert Card Flip to
  "pick one card, done", replace the fake slot reel with a real circular roulette
  wheel, and replace the crude gacha lever with a turnable gachapon dial.
- **Status:** Approved (brainstorming), ready for implementation plan.

## 1. Card Flip — back to the original design (reducer change)

Today `CardFlipFeature.start` does `random.shuffled(picks + picks)` — cards are
**duplicated into pairs** and the game only produces a result when two identical
cards are matched (`firstRevealedIndex`/`secondRevealedIndex`/`moves`/`hideMismatch`).
That memory-match detour was never the intent.

Target (the original spec): lay out **up to 6 distinct** shuffled cutouts
face-down; flipping **one** card reveals it and **that is the pick** — game over.

- `State`: `cards: [CutoutSnapshot]`, `revealedIndex: Int?`, `resultInfo`,
  computed `result: CutoutSnapshot?` = `cards[revealedIndex]`. **Remove**
  `firstRevealedIndex`, `secondRevealedIndex`, `moves`, and the `revealedIndices`
  set.
- `Action`: `start`, `flip(Int)`, `infoLoaded(GameResultInfo?)`, `playAgain`,
  `close`. **Remove** `hideMismatch`.
- `flip(index)` is a no-op once something is revealed (single-shot), and loads the
  meal info for the picked cutout.
- `CardFlipFeature.minimum` in `GameKind` stays as-is (3 is fine for 6 slots).
- Tests are rewritten to the new behavior: `start` lays distinct shuffled cards
  (no duplication), `flip(1)` selects `cards[1]` as the result, and a second
  `flip` is ignored. The mismatch test is deleted (that behavior no longer exists).
- `CardFlipView` drops the moves counter / mismatch shake / matched-pair glow and
  the "같은 누끼 두 장을 찾아봐" copy; it keeps the perspective 3D flip, the card
  backs, celebration on result, and the `ResultCard` hand-off. New copy: "끌리는
  카드 한 장을 골라 뒤집어봐".

## 2. Roulette — a real circular wheel

Today it is a vertical slot reel (`reel`, `landingIndex`, `reelOffset`) despite
being called 룰렛. Target: a **circular wheel**.

- **Reducer stays as the source of truth** — `spin` still picks the winner via
  `RandomClient` and records where it lands. The existing `reel` + `landingIndex`
  contract is reused unchanged (the reel array becomes the wheel's segment order,
  and `landingIndex` is the winning segment). **No reducer/test changes.**
- `RouletteView` is rebuilt: the wheel shows the **first N segments** of
  `store.reel` (N = `min(reel.count, 8)`… but must contain the winner, so the view
  uses the wheel slice `Array(store.reel.suffix(8))` and computes the winner's
  index within that slice from `landingIndex`) — each segment is a pie wedge
  (alternating pastel fills) with the cutout thumbnail placed at its mid-angle.
- A fixed **pointer** (a cherry triangle) sits at the top (12 o'clock). Spinning
  animates the wheel's `rotation` through several full turns and lands so the
  winning segment's mid-angle is exactly under the pointer:
  `rotation = 360 * turns - (segmentAngle * winnerSliceIndex + segmentAngle / 2)`.
- Timing: accelerate → decelerate → tiny overshoot settle, using the existing
  `spinDuration`; the result card still appears only after the wheel settles.
- Keeps: `PaperBackground`, `KitschSparkle` accents, `PillButton`/`OutlineButton`,
  haptics, glow/pulse on the winning wedge, the `ResultCard` hand-off.

## 3. Gacha — a turnable dial instead of a stick lever

Today the "lever" is a `Capsule` (28×118) with a circle on top, tilted 26° — it
reads as a stick, not a gachapon knob.

Target: a **round dial** mounted on the machine's face:
- a chocolate-outlined circular knob with a **slot groove** (a rounded rect across
  the middle) and a small dot marker,
- it **rotates** (not tilts): 0° at rest → 180° while dispensing → springs back,
- a **coin slot** detail (small dark rounded rect) above the dial, and a
  "1회 100엔" style micro-label is out of scope (no new copy).
- Everything else in the machine (drum, glass shine, tray, capsule dispense
  sequence) stays exactly as it is.

## 4. Global Constraints

- Card Flip is the **only** reducer/test change (§1). Roulette and Gacha are
  **view-only** (§2, §3) — no reducer/state/action edits, no other tests touched.
- Surgical edits; preserve existing components (`SoftCard`, `KitschIcon`,
  `KitschSparkle`, `ConfettiBurst`, `WashiTape`, `PaperBackground`,
  `KitschPressStyle`, `PillButton`, `OutlineButton`, `L10n`). Don't invent
  components.
- Deterministic animation math (index/angle-based) — no `Math.random`/`Date()`.
- Korean UI + `L10n` (add any new copy to all four `.lproj` files); light mode;
  iOS 18; Swift 6; TCA 1.26.
- Always `-skipMacroValidation`; never `tuist install`; never edit `Project.swift`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## 5. Testing

- New `CardFlipFeatureTests`: single-flip selection, second flip ignored,
  `start` lays distinct cards. Old pair/mismatch tests removed.
- Roulette/Gacha: existing reducer tests must pass **untouched**; views are
  build-verified. Wheel landing correctness is guaranteed by the reducer's
  `landingIndex` + the view's angle formula (documented above).
- Full suite green at the end; game feel device-verified by the user.

## 6. Out of Scope

New games; sound; Game Center scores; changing `RandomClient` selection; the
World Cup view (already polished this round).
