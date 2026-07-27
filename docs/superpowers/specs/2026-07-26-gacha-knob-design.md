# 가챠 손잡이 (Gacha Knob) — Design Spec

- **Date:** 2026-07-26
- **Scope:** Make the gacha machine's knob the real control — a proper gachapon
  knob you **turn by dragging** — and clean up the machine's front plate.
- **Status:** Approved (brainstorming), ready to implement.

## 1. Problem

- The dial is **decorative**: the actual control is a separate bottom
  `PillButton("레버 당기기")`, and the dial merely spins as a side effect. In a
  gachapon you grab the knob and turn it — that mismatch is the core letdown.
- The dial is flat: `Circle` + stroke + a groove bar + a dot. No metal depth, no
  chunky grip, no turn-direction cue, no detent feel.
- The front plate is cluttered/overflowing: a vestigial `arrow.down.circle`
  `KitschIcon` (52) + chocolate bar (18) + coin slot (10) + dial (62) squeezed into
  a 135 pt face.
- Copy says "레버를 **내려**" though it is a knob you turn.

## 2. The knob (`GachaKnob`, private to `GachaView`)

- **Bezel:** an outer ring filled with an `AngularGradient` of silvery stops
  (chrome feel), plus a static notch marker at 12 o'clock so rotation is readable.
- **Body:** a domed `Circle` with a `RadialGradient` (highlight top-left → mid →
  shadow bottom-right) and a thin `appChocolate` outline.
- **Grip:** a chunky T-bar — a `RoundedRectangle` (≈58×18) with its own vertical
  gradient and rounded lobes, so it reads as something you can pinch and turn.
- **Center:** a small screw dot.
- **Direction cue:** a static curved arrow arc (trimmed `Circle` stroke +
  arrowhead) hugging the knob's top-right, indicating clockwise.
- Rotation is applied to bezel/body/grip only — the notch, arrow, and plate stay put.

## 3. Interaction — drag to turn (tap also works)

- `DragGesture` on the knob: the angle is `atan2` of the touch relative to the
  knob's center (knob has a fixed size, so the center is a constant); per-move
  deltas are wraparound-normalized (±180°) and accumulated.
- **Detent haptics:** every 30° of accumulated turn bumps a counter that drives
  `.sensoryFeedback(.impact(weight: .light), trigger:)` — a "click" as it turns.
- **Threshold:** at ≥ 120° accumulated turn the pull fires: `store.send(.pullLever)`
  plus the existing drum spin/shake; the knob then completes to 360° and springs
  back to 0.
- **Tap fallback:** tapping the knob does exactly what crossing the threshold does
  (plus `accessibilityAddTraits(.isButton)` + an accessibility action), so the
  control is never a dead end.
- Ignored while `store.isSpinning`.
- The bottom `PillButton("레버 당기기")` is **removed** (the knob is the control);
  a hint line "손잡이를 돌려보세요" sits under the machine and hides once spinning.
  `OutlineButton("게임 나가기")` stays.

## 4. Front plate cleanup

The pink face becomes a real front plate (height ≈ 152):
- **top:** a horizontal coin slot capsule,
- **middle:** the knob (the hero element),
- **bottom:** a capsule **outlet door** (a darker rounded rect) positioned where
  the dispensed capsule lands, so the existing dispense animation reads correctly.
- The vestigial `arrow.down.circle` icon and chocolate bar are removed.
- Header copy becomes "손잡이를 돌려 오늘의 한 끼를 꺼내요".

## 5. Constraints

- **View-only:** `GachaFeature`, all reducers, and all tests are untouched.
- Preserve: drum + capsules + `drumTurns`/`drumShake` + glass shine, the dispense
  sequence (`capsuleDrop`/`capsuleOpen`/`capsuleSquash` + sparkles), `WashiTape`,
  `PaperBackground`, `ResultCard` hand-off and its resets, existing haptics.
- Deterministic math only. Korean copy via the project's `L10n` mechanism, added to
  all four `.lproj` files if keys are required.
- iOS 18, Swift 6. `-skipMacroValidation`; no `tuist install`; no `Project.swift` edit.

## 6. Verification

`tuist build FeatureKit` + app build + the full suite must stay green (nothing
outside this view changed). Knob feel (drag + detents) is device-verified by the
user; the simulator can render it but cutouts require a device.
