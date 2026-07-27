# 게임 폴리시 v2 (Hub Rework + Meticulous Game Animation) — Design Spec

- **Date:** 2026-07-26
- **Scope:** Rework the game hub layout (drop the intro banner, tighter cards, a
  real lock/progress affordance, full-width group row, staggered entrance) and do a
  meticulous design/animation pass on all four games + the result card.
- **Status:** Approved (brainstorming), ready for implementation plan.

## 1. Hub rework

Problems today: a large intro banner eats the first screen; `.appTitle` (20 pt)
titles wrap in two-column cards ("Food Tournament", "Sticker Roulette");
`minHeight: 170` makes cards oversized; locked cards are washed out at 0.5
opacity; nothing tells the user how many cutouts they have or how many more they
need; the lone group card sits awkwardly in a two-column grid.

Target:
- **No intro banner.** The screen starts with content.
- **Status strip** (compact, not a banner): a pill showing `내 누끼 N개`, plus —
  when at least one game is locked — the shortfall (`N개만 더 모으면 다 열려요`).
- **Solo cards, tighter:** icon 48, title `.appSection` (15 pt semibold, 1 line,
  `minimumScaleFactor(0.85)`), subtitle 2 lines max, `minHeight: 132`. Locked
  state = a small lock **badge** in the top-trailing corner + the icon
  desaturated, card body stays legible (no 0.5 blanket opacity).
- **Group row full width:** horizontal layout (icon → title/subtitle → chevron),
  visually distinct from the solo grid.
- **Staggered entrance:** cards fade/rise in with a per-index delay on appear.

## 2. Per-game animation polish

**Gacha (`GachaView`)**
- Drum shake + speed-up on lever pull; lever springs back after release.
- Glass shine overlay on the drum (a soft white diagonal highlight).
- Capsule landing gets a squash-and-stretch bounce; sparkle burst on split-open.

**Roulette (`RouletteView`)**
- Slot separators (thin dashed lines) so motion is readable.
- Speed illusion while spinning: reel rows slightly scaled/blurred (`.blur`
  ramping down as it settles).
- Overshoot then settle: animate slightly past the landing slot, then spring back.
- Winner slot pulses (glow ring) once it lands, before the result card.

**World Cup (`WorldCupView`)**
- Picking a contender: winner scales up and the loser slides out/fades, then the
  next pair slides in (replacing the current whole-view `.id(pairIndex)` swap with
  per-card transitions).
- Bracket progress dots (one per match in the round, filled as matches resolve).
- VS badge pops on each new pair.

**Card Flip (`CardFlipView`)**
- Real 3D perspective on the flip (`.rotation3DEffect` with `perspective:`).
- Matched pair: green-ish glow ring + scale pop; mismatch: a short shake.

**Result card (`ResultCard`)**
- Stamp-in entrance (scale from 1.15 with a slight rotation settle) so the reveal
  feels like a stamp landing, keeping the existing confetti/washi tape.

## 3. Global Constraints

- View-only work: **no reducer/state/action changes**, so all existing tests keep
  passing untouched (they are the regression net).
- Surgical edits to hand-evolved files; preserve existing components
  (`SoftCard`, `KitschIcon`, `KitschPressStyle`, `KitschSparkle`, `ConfettiBurst`,
  `WashiTape`, `PaperBackground`, `L10n`) — do not invent new components.
- Korean UI + `L10n`; light mode; iOS 18; Swift 6; TCA 1.26.
- Always `-skipMacroValidation`; never `tuist install`; never edit `Project.swift`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## 4. Testing

- No reducer changes → the full existing suite must stay green (run it at the end).
- Each view change is build-verified; the hub is additionally screenshot-verified
  in the simulator (it renders without cutout data).
- Game animations need real cutouts + a device for full feel → device-verified by
  the user (documented, not hidden).

## 5. Out of Scope

New games; sound; changing selection logic; Game Center scores; reducer/state
changes of any kind.
