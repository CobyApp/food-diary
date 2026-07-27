# 에러 처리 마무리 (Error Handling) — Design Spec

- **Date:** 2026-07-27
- **Scope:** Close the three failure paths deferred across earlier rounds: a
  silent meal-save failure, a nearby-search failure that spins forever, and
  orphaned cutout PNGs when a save throws midway.
- **Status:** Approved (brainstorming), ready for implementation plan.

## 1. Current state (verified in code)

- **Save:** `CaptureFeature.saveTapped` *does* have `catch:` → `.saveFailed`, which
  resets `isSaving`. But nothing is shown to the user — the save just doesn't
  happen and the button becomes tappable again. **Silent failure.**
- **Nearby search:** `PlacePickerFeature.task` has **no `catch:` at all**. If
  `placeSearch.nearby` throws, `.placesLoaded` never arrives and `isLoading`
  stays `true` — **the spinner runs forever**.
- **Orphaned PNGs:** `PersistenceActor.save` writes each cutout PNG through
  `imageStore.save` inside the loop, then calls `modelContext.save()`. If a later
  `imageStore.save` or the `modelContext.save()` throws, the already-written PNGs
  stay on disk with no DB row referencing them — **a storage leak.**

## 2. Target behavior

**A. Save failure is visible and retryable.**
Follow the pattern already used by `CollectionFeature` (`isDeleteErrorPresented` +
`dismissDeleteError` + an `.alert` in the view), so the codebase stays consistent:
- `CaptureFeature.State` gains `var isSaveErrorPresented = false`.
- `.saveFailed` sets it `true` (and keeps resetting `isSaving`).
- New action `dismissSaveError` clears it.
- `CaptureView` shows an alert: title "저장하지 못했어요", message
  "잠시 후 다시 시도해주세요.", buttons **다시 시도** (re-sends `.saveTapped`) and
  **확인** (`dismissSaveError`). Because `.saveFailed` leaves the picked
  candidates/memo/place intact, retry is a genuine retry — nothing is lost.

**B. Nearby-search failure stops the spinner and offers retry.**
- `PlacePickerFeature.State` gains `var isSearchFailed = false`.
- `.task` gets `catch:` → new action `.searchFailed`, which sets
  `isLoading = false`, `isSearchFailed = true`.
- Retrying: `.task` (re-sent) clears `isSearchFailed` and starts over.
- `PlacePickerView` renders, in the place of the list when `isSearchFailed`:
  a short message ("근처 식당을 불러오지 못했어요") plus a **다시 시도** button
  sending `.task`. Manual entry stays available, so the user is never stuck.

**C. Save rolls back the PNGs it wrote.**
- `PersistenceActor.save` tracks the file names it wrote; on any throw it deletes
  them before rethrowing:
  ```swift
  var written: [String] = []
  do { … written.append(name) … try modelContext.save() }
  catch { for name in written { try? imageStore.delete(name) }; throw error }
  ```
- Behavior on success is unchanged.

## 3. Testing

- **ClientKit:** `test_saveMeal_whenAnImageWriteFails_rollsBackWrittenImages` — an
  `ImageStore` stub whose `save` throws on the **second** cutout and whose `delete`
  records names; assert the first written name was deleted and the call threw.
  (Deterministic; no need to force a SwiftData failure.)
- **FeatureKit — Capture:** `.saveFailed` sets `isSaveErrorPresented` and clears
  `isSaving`; `dismissSaveError` clears the flag. A stubbed throwing `saveMeal`
  drives `saveTapped → saveFailed`.
- **FeatureKit — PlacePicker:** a throwing `nearby` drives `.task → searchFailed`
  with `isLoading == false`; re-sending `.task` clears `isSearchFailed`.
- Views are build-verified; the full suite must stay green.

## 4. Constraints

- Surgical edits to hand-evolved files; keep every unrelated behavior (multi-select
  delete, streak, profile, games, recap, widget) untouched.
- Korean UI copy via the project's existing `L10n` mechanism; add keys to all four
  `.lproj` files if the mechanism requires registration.
- iOS 18, Swift 6, TCA 1.26. Always `-skipMacroValidation`; never `tuist install`;
  never edit `Project.swift`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## 5. Out of Scope

A global error-banner system; retry with backoff; offline queueing; surfacing
`allCutouts`/`allMeals` load failures (those already fall back to empty lists,
which reads as an empty state rather than a hang).
