# 게임 퀄리티 업 (Game Quality Pass) — Design Spec

- **Date:** 2026-07-25
- **Scope:** Make the four decider games feel like real games: the reel/capsule
  must land on the ACTUAL winner, contenders must show real food info, results
  must be rich, and the hub must separate solo vs group play.
- **Status:** Approved (brainstorming), ready for implementation plan.

## 1. Diagnosis (what's actually weak today)

1. **Roulette lies.** `reelOffset` animates to a fixed offset unrelated to the
   picked winner, then the result card appears after a blind 1.5 s. The stopped
   image ≠ the actual pick, and there's no pointer marking the winning slot.
2. **Gacha has no payoff.** The drum spins, but the chosen capsule never drops
   into the tray/opens — just a 1.1 s blind wait, then the result card.
3. **World Cup contenders are anonymous.** Cards show placeholder
   "LEFT PICK"/"RIGHT PICK" instead of the food's restaurant / one-line memo, so
   there's nothing to actually choose between.
4. **Result card is thin.** Only the place name; no date, no 한줄평, no rating.
5. **Hub is unsorted and inconsistent.** Solo games and the group game sit in one
   grid, and the "함께 정하기" card uses a raw emoji, centered layout, and
   `.buttonStyle(.plain)` while every other card uses `KitschIcon`, a leading
   layout, a slight rotation, and `KitschPressStyle` — it visibly doesn't belong.

## 2. Global Constraints

- Surgical, additive-where-possible edits to the existing game files. Do NOT
  change Collection/Capture/Map/Achievements/Recap/Profile/widget/streak flows.
- Randomness only via `RandomClient`; the reducer decides the winner, the view
  only animates toward it (so what you see is what was picked).
- Pastel/kitsch DesignSystem + `L10n`; light mode; Korean UI strings.
- iOS 18, Swift 6, TCA 1.26. Always `-skipMacroValidation`; never `tuist install`;
  do not edit `Project.swift`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## 3. Shared richer result — `GameResultInfo`

Replace the four games' `resultPlace: String?` + `placeLoaded(String?)` with one
shared value type and action payload:

```swift
public struct GameResultInfo: Equatable, Sendable {
    public let placeName: String
    public let dateText: String
    public let memo: String
    public let rating: Int?
}
```

- Built from `persistence.mealByCutout(id)`: `place?.name`, `eatenAt` formatted
  (`.dateTime.month().day().weekday()`), `memo`, `rating`.
- Each of `GachaFeature`, `RouletteFeature`, `CardFlipFeature`, `WorldCupFeature`
  swaps `resultPlace`/`championPlace` → `resultInfo`/`championInfo: GameResultInfo?`
  and `placeLoaded(String?)` → `infoLoaded(GameResultInfo?)`. Their existing tests
  are updated to the new action/state names (assertions preserved in spirit).
- **`ResultCard`** takes `info: GameResultInfo?` and renders: place name (or
  "오늘의 한 끼"), a date chip, the memo in quotes when present, and a star row
  when `rating != nil` — on top of the existing confetti/washi-tape design.

## 4. Roulette lands on the winner

- `RouletteFeature.State` gains `landingIndex: Int?`.
- On `.spin`: pick the winner via `random.pick(cutouts)`, then rebuild
  `reel = (0..<3).flatMap { random.shuffled(cutouts) } + [winner]` and set
  `landingIndex = reel.count - 1`, `result = winner`. So the winner is a real slot
  at a known index.
- `RouletteView` animates `reelOffset` to center that exact slot
  (`-CGFloat(landingIndex) * slotHeight`), adds a **center pointer line** (a
  cherry-colored bar + sparkles marking the winning row), and only then reveals
  the result card. What stops under the pointer IS the winner.

## 5. Gacha dispenses the chosen capsule

- No reducer change (the winner is already known when `result` is set).
- `GachaView` gains a dispense phase: after `.pullLever`, the drum spins; then a
  capsule containing the winner's cutout **animates down into the tray**, lands
  with a bounce, and **splits open** (two halves part) revealing the cutout, which
  scales up into the result card. Uses the existing 1.1 s window (extended
  slightly), sensory feedback on land.

## 6. World Cup + Card Flip polish

- **World Cup:** `State` gains `info: [UUID: GameResultInfo]`, loaded on `.start`
  (from `persistence.allMeals()`), so each contender card shows its **restaurant
  name** and (if present) a short 한줄평 under the cutout instead of
  "LEFT PICK"/"RIGHT PICK". Add a round-transition banner ("8강 → 4강") shown
  briefly when the round advances, plus a "이긴 쪽" pop on the picked card.
- **Card Flip:** add a win celebration when all pairs are matched / the result is
  found (a sparkle burst + the matched pair scaling), and a brief "매치!" badge on
  a successful pair.

## 7. Hub separation

`GameHubView` becomes two labeled sections inside the existing `ScreenScaffold`:
- **"혼자 결정"** — the four `GameKind` cards (unchanged design).
- **"같이 결정"** — the group-decider card, **restyled to match**: `KitschIcon`
  (`"person.2.fill"` on `.appLavender`), leading `VStack`, title/subtitle in the
  same fonts, `minHeight: 170`, slight rotation, `KitschPressStyle`, and a
  "게임센터" caption. Section headers use `.appSection` with a small caption.

## 8. Testing

- `GameResultInfo` plumbing: each of the four reducers' existing tests updated to
  `infoLoaded`/`resultInfo` (same behavior asserted).
- `RouletteFeature`: `.spin` sets `result` to the injected pick AND makes
  `reel.last == winner` with `landingIndex == reel.count - 1` (new assertions).
- `WorldCupFeature`: `.start` loads `info` from stubbed `allMeals` (new test).
- `GameHubFeature`: unchanged behavior (existing tests keep passing).
- Views (dispense animation, pointer, celebration, hub sections) are
  build-verified + simulator-screenshot verified where data-independent; full
  game feel with real cutouts is device-verified by the user.

## 9. Out of Scope

New game types; sound effects; leaderboards/Game Center scores; persisting game
history; changing the games' underlying selection logic (still `RandomClient`).
