# Error Handling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close three deferred failure paths — orphaned PNGs on a failed save, a silent save failure, and a nearby-search failure that spins forever.

**Architecture:** Task 1 hardens `PersistenceActor.save` (rollback). Tasks 2–3 add user-visible, retryable error states to `CaptureFeature`/`CaptureView` and `PlacePickerFeature`/`PlacePickerView`, following the `isDeleteErrorPresented` pattern already used by `CollectionFeature`.

**Tech Stack:** SwiftUI, TCA 1.26, SwiftData, iOS 18, Swift 6.

## Global Constraints

- **Surgical.** Read each file fully first; keep every unrelated behavior (multi-select delete, streak, profile, games, recap, widget, decoration) byte-for-byte in behavior.
- Follow the existing error pattern (`isXErrorPresented` + `dismissXError` + `.alert` in the view) — do not introduce a new error framework.
- Korean UI copy through the project's existing `L10n` mechanism; check how neighboring strings are handled and match it (add keys to all four `Sources/FoodDiary/Resources/*.lproj/Localizable.strings` if registration is required).
- Build `tuist build FeatureKit` / `tuist build ClientKit`; tests `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:<Bundle>/<Class> -skipMacroValidation`. Always `-skipMacroValidation`. Never `tuist install`; never edit `Project.swift`.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Task 1: Roll back written PNGs when a save throws

**Files:**
- Modify: `Sources/ClientKit/PersistenceClient.swift` (the `PersistenceActor.save` method only)
- Modify: `Tests/ClientKitTests/PersistenceClientTests.swift` (append one test)

**Interfaces:** no signature changes — `save(place:memo:rating:cutouts:imageStore:)` keeps its shape and success behavior; only the failure path changes.

- [ ] **Step 1: Append the failing test**

Add to `Tests/ClientKitTests/PersistenceClientTests.swift` (inside the class):
```swift
    func test_saveMeal_whenAnImageWriteFails_rollsBackWrittenImages() async throws {
        struct WriteFailure: Error {}
        let container = try ModelContainer(
            for: Meal.self, FoodCutout.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        // Fails on the SECOND write; records every delete so we can assert rollback.
        let writes = LockIsolated(0)
        let deleted = LockIsolated<[String]>([])
        let store = ImageStore(
            save: { _ in
                let index = writes.withValue { value -> Int in
                    value += 1
                    return value
                }
                if index == 2 { throw WriteFailure() }
                return "written-\(index).png"
            },
            load: { _ in nil },
            delete: { name in deleted.withValue { $0.append(name) } }
        )
        let client = PersistenceClient.live(container: container, imageStore: store)

        do {
            _ = try await client.saveMeal(
                nil, "rollback", nil,
                [NewCutout(pngData: Data([1]), label: nil),
                 NewCutout(pngData: Data([2]), label: nil)]
            )
            XCTFail("save should have thrown")
        } catch {
            // expected
        }

        XCTAssertEqual(deleted.value, ["written-1.png"], "the first written PNG must be cleaned up")
        let meals = try await client.allMeals()
        XCTAssertTrue(meals.isEmpty, "no meal should be persisted when the save fails")
    }
```
> `LockIsolated` comes from `ConcurrencyExtras` (already in the dependency graph via TCA). If it isn't importable in this test target, use a simple `final class Box: @unchecked Sendable` holding the values instead — keep the assertions identical.

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:ClientKitTests/PersistenceClientTests/test_saveMeal_whenAnImageWriteFails_rollsBackWrittenImages -skipMacroValidation 2>&1 | tail -6`
Expected: FAIL — `deleted.value` is empty (no rollback today).

- [ ] **Step 3: Add the rollback**

In `PersistenceActor.save`, wrap the write loop + insert + save so any throw cleans up the PNGs already written, then rethrows:
```swift
    func save(
        place: PlaceInfo?, memo: String, rating: Int?, cutouts: [NewCutout],
        imageStore: ImageStore
    ) throws -> MealSnapshot {
        let meal = Meal(memo: memo, rating: rating)
        meal.place = place
        // Track what we wrote so a later failure doesn't leave orphaned PNGs.
        var written: [String] = []
        do {
            for new in cutouts {
                let name = try imageStore.save(new.pngData)
                written.append(name)
                let cutout = FoodCutout(fileName: name, label: new.label)
                cutout.meal = meal
                meal.cutouts.append(cutout)
            }
            modelContext.insert(meal)
            try modelContext.save()
        } catch {
            for name in written { try? imageStore.delete(name) }
            modelContext.rollback()
            throw error
        }
        return meal.snapshot()
    }
```
(Keep the rest of the actor untouched.)

- [ ] **Step 4: Green + full ClientKit suite**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:ClientKitTests -skipMacroValidation 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **` — the new test passes and every existing ClientKit test still passes (the success path is unchanged).

- [ ] **Step 5: Commit**

```bash
git add Sources/ClientKit/PersistenceClient.swift Tests/ClientKitTests/PersistenceClientTests.swift
git commit -m "fix(clientkit): roll back written cutout PNGs when a save fails

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Make a save failure visible and retryable

**Files:**
- Modify: `Sources/FeatureKit/Capture/CaptureFeature.swift`
- Modify: `Sources/FeatureKit/Capture/CaptureView.swift`
- Modify: `Tests/FeatureKitTests/CaptureFeatureTests.swift` (append tests)

**Interfaces:**
- `CaptureFeature.State` gains `public var isSaveErrorPresented = false`.
- `CaptureFeature.Action` gains `case dismissSaveError`.
- `.saveFailed` keeps `state.isSaving = false` and additionally sets `isSaveErrorPresented = true`.

- [ ] **Step 1: Append the failing tests**

Add to `Tests/FeatureKitTests/CaptureFeatureTests.swift` (inside the class):
```swift
    @MainActor
    func test_saveFailure_presentsErrorAndClearsSaving() async {
        struct SaveFailure: Error {}
        let store = TestStore(
            initialState: CaptureFeature.State(
                candidates: [.init(id: UUID(), pngData: Data([1]), isSelected: true)]
            )
        ) {
            CaptureFeature()
        } withDependencies: {
            $0.persistence.saveMeal = { _, _, _, _ in throw SaveFailure() }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(\.saveFailed) {
            $0.isSaving = false
            $0.isSaveErrorPresented = true
        }
        // The picked candidate survives, so "다시 시도" is a real retry.
        XCTAssertEqual(store.state.candidates.count, 1)

        await store.send(.dismissSaveError) { $0.isSaveErrorPresented = false }
    }
```
> If `CaptureFeature.State`'s memberwise init doesn't expose `candidates`, seed it the way the existing tests in this file do — match the current file.

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/CaptureFeatureTests/test_saveFailure_presentsErrorAndClearsSaving -skipMacroValidation 2>&1 | tail -6`
Expected: FAIL — no member `isSaveErrorPresented`.

- [ ] **Step 3: Extend the reducer**

- In `State`, next to `isSaving`: `public var isSaveErrorPresented = false`.
- In `Action`, next to `saveFailed`: `case dismissSaveError`.
- Update the `.saveFailed` case body to:
```swift
            case .saveFailed:
                state.isSaving = false
                state.isSaveErrorPresented = true
                return .none

            case .dismissSaveError:
                state.isSaveErrorPresented = false
                return .none
```

- [ ] **Step 4: Add the alert to `CaptureView`**

Attach an alert to the same view chain that already carries the other modifiers (match the style `CollectionView` uses for its delete-error alert):
```swift
        .alert(
            L10n.text("저장하지 못했어요"),
            isPresented: Binding(
                get: { store.isSaveErrorPresented },
                set: { if !$0 { store.send(.dismissSaveError) } }
            )
        ) {
            Button(L10n.text("다시 시도")) { store.send(.saveTapped) }
            Button(L10n.text("확인"), role: .cancel) { store.send(.dismissSaveError) }
        } message: {
            Text(L10n.text("잠시 후 다시 시도해주세요."))
        }
```
Match how neighboring strings in this file are localized (`L10n.text` vs a literal); if `CollectionView`'s alert uses plain literals, mirror that instead. Add any new keys to all four `.lproj` files if the project registers keys.

- [ ] **Step 5: Green + build**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/CaptureFeatureTests -skipMacroValidation 2>&1 | tail -5`
Then: `tuist build FeatureKit`
Expected: `** TEST SUCCEEDED **` (new + existing Capture tests), `Build Succeeded`.

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Capture/CaptureFeature.swift Sources/FeatureKit/Capture/CaptureView.swift Tests/FeatureKitTests/CaptureFeatureTests.swift Sources/FoodDiary/Resources
git commit -m "fix(featurekit): surface save failures with a retryable alert

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Stop the endless spinner on a nearby-search failure

**Files:**
- Modify: `Sources/FeatureKit/Capture/PlacePickerFeature.swift`
- Modify: `Sources/FeatureKit/Capture/PlacePickerView.swift`
- Modify: `Tests/FeatureKitTests/PlacePickerFeatureTests.swift` (append tests)

**Interfaces:**
- `State` gains `public var isSearchFailed = false`.
- `Action` gains `case searchFailed`.
- `.task` gains `catch:` → `.searchFailed`, and clears `isSearchFailed` when it starts.

- [ ] **Step 1: Append the failing tests**

Add to `Tests/FeatureKitTests/PlacePickerFeatureTests.swift` (inside the class):
```swift
    @MainActor
    func test_nearbyFailure_stopsLoadingAndFlagsFailure() async {
        struct SearchFailure: Error {}
        let store = TestStore(
            initialState: PlacePickerFeature.State(
                coordinate: Coordinate(latitude: 1, longitude: 2)
            )
        ) {
            PlacePickerFeature()
        } withDependencies: {
            $0.placeSearch.nearby = { _ in throw SearchFailure() }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.searchFailed) {
            $0.isLoading = false
            $0.isSearchFailed = true
        }
    }

    @MainActor
    func test_retryClearsTheFailureFlag() async {
        let place = PlaceInfo(id: "1", name: "라멘집", address: "후쿠오카")
        let store = TestStore(
            initialState: PlacePickerFeature.State(
                coordinate: Coordinate(latitude: 1, longitude: 2)
            )
        ) {
            PlacePickerFeature()
        } withDependencies: {
            $0.placeSearch.nearby = { _ in [place] }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.task) {
            $0.isLoading = true
            $0.isSearchFailed = false
        }
        await store.receive(\.placesLoaded) {
            $0.isLoading = false
            $0.places = [place]
        }
    }
```
> Match how the existing tests in this file construct `State` (its init signature).

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/PlacePickerFeatureTests -skipMacroValidation 2>&1 | tail -6`
Expected: FAIL — no member `isSearchFailed` / `searchFailed`.

- [ ] **Step 3: Extend the reducer**

- `State`: add `public var isSearchFailed = false` (after `isLoading`).
- `Action`: add `case searchFailed`.
- Replace the `.task` case body with:
```swift
            case .task:
                guard let coordinate = state.coordinate else { return .none }
                state.isLoading = true
                state.isSearchFailed = false
                return .run { send in
                    let places = try await placeSearch.nearby(coordinate)
                    await send(.placesLoaded(places))
                } catch: { _, send in
                    await send(.searchFailed)
                }
```
- Add:
```swift
            case .searchFailed:
                state.isLoading = false
                state.isSearchFailed = true
                return .none
```

- [ ] **Step 4: Show the failure + retry in `PlacePickerView`**

Where the nearby list/spinner renders, add a failure branch (keep manual entry available below it, unchanged):
```swift
            if store.isSearchFailed {
                VStack(spacing: 10) {
                    Text(L10n.text("근처 식당을 불러오지 못했어요"))
                        .font(.appBody).foregroundStyle(.appMuted)
                    OutlineButton("다시 시도") { store.send(.task) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
```
Place it so it replaces (not stacks under) the empty list area, and make sure the existing spinner only shows while `store.isLoading`. Match the file's existing components/localization style (`OutlineButton` exists; if this view uses a different button component, use that one).

- [ ] **Step 5: Green + build + FULL suite**

Run: `xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -only-testing:FeatureKitTests/PlacePickerFeatureTests -skipMacroValidation 2>&1 | tail -5`
Then `tuist build FeatureKit`, then the app build:
`xcodebuild build -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'generic/platform=iOS Simulator' -skipMacroValidation 2>&1 | tail -3`
Then the FULL suite:
`xcodebuild test -workspace FoodDiary.xcworkspace -scheme FoodDiary -destination 'id=3B1E5795-617D-4955-8048-0CC8AD03BE95' -skipMacroValidation 2>&1 | tail -6`
Expected: `** TEST SUCCEEDED **`, `Build Succeeded`, `BUILD SUCCEEDED`, and the full suite green.

- [ ] **Step 6: Commit**

```bash
git add Sources/FeatureKit/Capture/PlacePickerFeature.swift Sources/FeatureKit/Capture/PlacePickerView.swift Tests/FeatureKitTests/PlacePickerFeatureTests.swift Sources/FoodDiary/Resources
git commit -m "fix(featurekit): handle nearby-search failure with a retry instead of an endless spinner

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review Notes (against spec)

- **Spec §2C rollback** → Task 1 (+ a deterministic test using a stub that throws on the second write).
- **Spec §2A visible, retryable save failure** → Task 2 (state/action/alert, candidates preserved so retry is real).
- **Spec §2B nearby failure stops the spinner + retry** → Task 3 (catch, flag, retry button, manual entry still available).
- **Spec §3 testing** → one ClientKit test + three FeatureKit tests; full suite verified at the end of Task 3.
- **Spec §4 constraints** → existing `isXErrorPresented` pattern reused; no new error framework; unrelated flows untouched.

## Notes for the implementer

- Always `-skipMacroValidation`. Booted sim UDID `3B1E5795-617D-4955-8048-0CC8AD03BE95` (else `xcrun simctl list devices booted`).
- If `LockIsolated` isn't available in `ClientKitTests`, swap in a tiny `@unchecked Sendable` box — keep the assertions.
- These files have been hand-edited a lot: read them first and adapt the snippets to the current code rather than pasting over unrelated logic.
- If `xcodebuild` seems to reuse stale binaries, clear this project's DerivedData and retry (this has happened in earlier rounds).
