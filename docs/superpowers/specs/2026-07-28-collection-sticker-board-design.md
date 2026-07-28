# Collection Board: Touchable Stickers

## Problem

The collection screen is the app's main screen and it feels inert.

The cause is in the code, not in the visual design. `ParallaxMotion`'s
`.parallax(8)` modifier applies **the same 8pt offset to every tile**, so the
whole grid slides as one slab while the background stays fixed. Parallax reads as
depth only when layers move by *different* amounts, so tilting the device
currently looks like nothing happens. Interaction is also thin: a tap flips a
tile, and that is all.

## Direction

Make the stickers feel physically touchable, and make them react to each other.
Chosen over two alternatives (a depth/glass "sticker board behind glass" look,
and an ambient moving background) because touch manipulation is the strongest of
the three and matches the sticker-book metaphor the app is built on.

## Design

### 1. One sequenced gesture for hold-and-peel

A bare `DragGesture` on a tile fights the vertical `ScrollView` that
`ScreenScaffold` owns. So press and drag are a single sequenced gesture —
`LongPressGesture(minimumDuration: 0.25).sequenced(before: DragGesture())`:

| Phase | Result |
| --- | --- |
| Hold still | The native record/select/delete context menu stays available |
| Hold 0.25s, then move | The sticker lifts, follows the finger, and tilts into the drag |
| Release | It springs home with the flick's momentum carried into the spring |
| Short tap | Unchanged — flips the tile, or toggles selection while editing |

Momentum comes from `Animation.interpolatingSpring(initialVelocity:)`, fed by the
gesture's own `velocity`, rather than from a hand-rolled physics loop. A hard
flick overshoots home and settles; a slow release just eases back.

**Preserved:** the tile `contextMenu`, because the product interaction calls for
record/select/delete actions on a stationary long press. The peel gesture runs
simultaneously but does not lift until the finger actually travels, so holding
still remains a menu gesture.

### 2. Motion that is relative, not uniform

- **Neighbour repulsion.** A `PeelCoordinator` (`@Observable`) holds the grid cell
  of the sticker being held. Every other tile reads it and steps aside by a
  distance-falloff amount, so touching one sticker visibly disturbs the ones
  around it. Repulsion is computed in **grid cells**, not screen points, which
  avoids per-tile geometry plumbing and keeps the math testable.
- **Staggered gravity lean.** Tilt amplitude and rotation are varied per tile
  index, so the wall no longer moves as one piece — the stickers lean like
  loosely taped paper, each a little differently.

Fixed column count (3 compact / 5 regular size class) replaces
`GridItem(.adaptive)`. Both features above need a known column count to map an
index to a cell, and 3 columns is within a few points of what the adaptive grid
already produced on a phone.

### 3. Pull to spill

`ScreenScaffold` gains an optional `onRefresh` closure (defaults to `nil`, so no
other screen changes). Pulling down drops the tiles off the bottom in index order
with a stagger, reloads, then springs them back in.

### 4. Tilt to browse

When roll passes 0.55 and holds for 0.3s, the column on that side pops forward
and its tiles reveal a place-name chip. Releasing the tilt hides them. The hold
is debounced with `.task(id:)`, and the place names already live in
`store.cutoutMealInfo`.

## Components

| File | Responsibility |
| --- | --- |
| `DesignSystem/StickerBoardMotion.swift` (new) | Pure math: per-index lean, neighbour repulsion, release velocity, spill stagger, revealed column. No SwiftUI, no CoreMotion. |
| `DesignSystem/PeelableSticker.swift` (new) | The sequenced gesture modifier and `PeelCoordinator`. |
| `DesignSystem/ParallaxMotion.swift` | Sensor only: adds low-pass smoothing (raw 30Hz roll jitters), stops updates on disappear, drops the uniform `.parallax` modifier. |
| `DesignSystem/Components/ScreenScaffold.swift` | Optional `onRefresh`. |
| `Collection/CollectionView.swift` | Wiring, header select button, spill, tilt reveal. |

## Testing

Every number the board animates lives in `StickerBoardMotion` as a pure
function, so it is covered on the simulator and in CI:

- lean amplitude differs between indices (the bug being fixed) and is bounded
- repulsion falls to zero at and beyond its radius, pushes directly away from the
  held cell, and returns zero for a zero-distance cell instead of `NaN`
- release velocity is zero for a negligible drag and is clamped for a hard flick
- spill delay grows with index and saturates at its cap
- revealed column is `nil` below the tilt threshold, leftmost for a negative
  roll, rightmost for a positive one

Gestures, gyro response, and the spill's feel need the device — verified on Coby,
not claimed from the simulator.

## Out of scope

Free-form sticker positions that persist. Dragging rearranges nothing: a
released sticker always returns to its grid slot. Persisted positions would mean
a new coordinate model, collision handling, and a rewrite of edit mode and
multi-select for no gain in how the screen feels.
