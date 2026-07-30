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

    /// The recap is a picture of the board, so whatever is on the board is what
    /// gets handed over — there is no range to carry.
    @MainActor
    func test_recapTakesTheBoardAsItStands() async {
        let onBoard = [
            FoodEntrySnapshot(id: UUID(), fileName: "a.png", eatenAt: Date(), tags: ["라멘"]),
            FoodEntrySnapshot(id: UUID(), fileName: "b.png", eatenAt: Date()),
        ]
        let store = TestStore(initialState: CollectionFeature.State()) {
            CollectionFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.recapButtonTapped(onBoard)) {
            $0.recap = RecapFeature.State(cutouts: onBoard)
        }
        await store.send(.recap(.presented(.close))) {
            $0.recap = nil
        }
    }

}
