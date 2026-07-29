import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class CollectionFeatureTests: XCTestCase {
    @MainActor
    func test_onAppear_loadsCutouts() async {
        let sample = [
            FoodEntrySnapshot(id: UUID(), fileName: "a.png", eatenAt: Date(), label: "라멘"),
        ]
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        } withDependencies: {
            $0.persistence.allEntries = { sample }
        }

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.cutoutsLoaded) {
            $0.isLoading = false
            $0.cutouts = sample
        }
        // The index is built from the foods themselves, so it is never empty when
        // there are foods.
        await store.receive(\.mealInfoLoaded) {
            $0.cutoutMealInfo = [
                sample[0].id: CutoutMealInfo(
                    placeName: "",
                    dateText: sample[0].eatenAt.formatted(.dateTime.month().day()),
                    tags: [],
                    rating: nil
                ),
            ]
        }
    }

    @MainActor
    func test_onAppear_loadsMealInfoForCutouts() async {
        let cutoutID = UUID()
        let eatenAt = Date()
        let place = PlaceInfo(id: "place-1", name: "스시야", address: "서울")
        // The food's information lives on the food itself now.
        let cutout = FoodEntrySnapshot(
            id: cutoutID, fileName: "a.png", eatenAt: eatenAt,
            place: place, tags: ["맛있었다"], rating: 5
        )
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        } withDependencies: {
            $0.persistence.allEntries = { [cutout] }
        }
        let expectedDateText = eatenAt.formatted(.dateTime.month().day())

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.cutoutsLoaded) {
            $0.isLoading = false
            $0.cutouts = [cutout]
        }
        await store.receive(\.mealInfoLoaded) {
            $0.cutoutMealInfo = [
                cutoutID: CutoutMealInfo(
                    placeName: "스시야",
                    dateText: expectedDateText,
                    tags: ["맛있었다"],
                    rating: 5
                ),
            ]
        }
    }

    @MainActor
    func test_multiSelect_thenDelete_removesOnlySelectedCutouts() async {
        let first = FoodEntrySnapshot(
            id: UUID(), fileName: "first.png", eatenAt: Date(), label: nil
        )
        let second = FoodEntrySnapshot(
            id: UUID(), fileName: "second.png", eatenAt: Date(), label: nil
        )
        var initialState = CollectionFeature.State()
        initialState.cutouts = [first, second]
        let store = TestStore(initialState: initialState) {
            CollectionFeature()
        } withDependencies: {
            $0.persistence.deleteEntries = { ids in
                XCTAssertEqual(ids, [first.id])
            }
        }

        await store.send(.editButtonTapped) {
            $0.isEditing = true
        }
        await store.send(.selectionToggled(first.id)) {
            $0.selectedCutoutIDs = [first.id]
        }
        await store.send(.deleteSelectedConfirmed) {
            $0.isDeleting = true
        }
        await store.receive(\.cutoutsDeleted) {
            $0.cutouts = [second]
            $0.selectedCutoutIDs = []
            $0.isDeleting = false
            $0.isEditing = false
        }
    }

    @MainActor
    func test_selectAll_togglesEveryCutout() async {
        let cutouts = [
            FoodEntrySnapshot(id: UUID(), fileName: "a.png", eatenAt: Date(), label: nil),
            FoodEntrySnapshot(id: UUID(), fileName: "b.png", eatenAt: Date(), label: nil),
        ]
        var initialState = CollectionFeature.State()
        initialState.cutouts = cutouts
        initialState.isEditing = true
        let store = TestStore(initialState: initialState) {
            CollectionFeature()
        }

        await store.send(.selectAllTapped) {
            $0.selectedCutoutIDs = Set(cutouts.map(\.id))
        }
        await store.send(.selectAllTapped) {
            $0.selectedCutoutIDs = []
        }
    }

    @MainActor
    func test_longPressSelection_startsWithPressedCutoutSelected() async {
        let cutout = FoodEntrySnapshot(
            id: UUID(), fileName: "pressed.png", eatenAt: Date(), label: nil
        )
        var initialState = CollectionFeature.State()
        initialState.cutouts = [cutout]
        let store = TestStore(initialState: initialState) { CollectionFeature() }

        await store.send(.beginSelection(cutout.id)) {
            $0.isEditing = true
            $0.selectedCutoutIDs = [cutout.id]
        }
    }

    @MainActor
    func test_onAppear_whenLoadFails_clearsLoadingAndShowsEmpty() async {
        struct LoadError: Error {}
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        } withDependencies: {
            $0.persistence.allEntries = { throw LoadError() }
        }

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.cutoutsLoaded) {
            $0.isLoading = false
            $0.cutouts = []
        }
    }

    @MainActor
    func test_achievementsButton_presentsAndDismisses() async {
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.achievementsButtonTapped) {
            $0.achievements = AchievementsFeature.State()
        }
        await store.send(.achievements(.presented(.close))) {
            $0.achievements = nil
        }
    }

    @MainActor
    func test_recapDateRange_isPassedWhenPresentingRecap() async {
        let today = Calendar.current.startOfDay(
            for: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let start = Calendar.current.date(byAdding: .day, value: -6, to: today) ?? today
        let store = TestStore(
            initialState: CollectionFeature.State(
                recapStartDate: today,
                recapEndDate: today
            )
        ) {
            CollectionFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.recapDateRangeChanged(start: start, end: today)) {
            $0.recapStartDate = start
            $0.recapEndDate = today
        }
        await store.send(.recapButtonTapped) {
            $0.recap = RecapFeature.State(startDate: start, endDate: today)
        }
        await store.send(.recap(.presented(.close))) {
            $0.recap = nil
        }
    }

    @MainActor
    func test_cutoutTapped_presentsAndDismissesDetail() async {
        let id = UUID()
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.cutoutTapped(id)) { $0.selectedCutoutID = id }
        await store.send(.dismissCutoutDetail) { $0.selectedCutoutID = nil }
    }
}
