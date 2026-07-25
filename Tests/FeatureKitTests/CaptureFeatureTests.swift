import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit
@testable import ClientKit

final class CaptureFeatureTests: XCTestCase {
    @MainActor
    func test_photoPicked_extractsCutoutsAndCoordinate() async {
        let store = TestStore(initialState: CaptureFeature.State()) {
            CaptureFeature()
        } withDependencies: {
            $0.foodCutout.extract = { _ in [Cutout(pngData: Data([1])), Cutout(pngData: Data([2]))] }
            $0.photoLocation.coordinate = { _ in Coordinate(latitude: 1, longitude: 2) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.photoPicked(Data([9]))) {
            $0.photoData = Data([9])
            $0.isProcessing = true
        }
        await store.receive(\.processingFinished) {
            $0.isProcessing = false
            $0.coordinate = Coordinate(latitude: 1, longitude: 2)
            $0.candidates = [
                .init(id: $0.candidates[0].id, pngData: Data([1]), isSelected: true),
                .init(id: $0.candidates[1].id, pngData: Data([2]), isSelected: true),
            ]
        }
    }

    @MainActor
    func test_photoPicked_whenExtractionFails_endsProcessingWithNoCandidates() async {
        struct ExtractError: Error {}
        let store = TestStore(initialState: CaptureFeature.State()) {
            CaptureFeature()
        } withDependencies: {
            $0.foodCutout.extract = { _ in throw ExtractError() }
            $0.photoLocation.coordinate = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.photoPicked(Data([9]))) {
            $0.photoData = Data([9])
            $0.isProcessing = true
        }
        await store.receive(\.processingFinished) {
            $0.isProcessing = false
            $0.coordinate = nil
            $0.candidates = []
        }
    }

    @MainActor
    func test_rotateCandidate_replacesPixelsBeforeSaving() async {
        let id = UUID()
        let store = TestStore(
            initialState: CaptureFeature.State(
                candidates: [.init(id: id, pngData: Data([1]))]
            )
        ) {
            CaptureFeature()
        } withDependencies: {
            $0.foodCutout.rotateClockwise = { data in
                XCTAssertEqual(data, Data([1]))
                return Data([2])
            }
        }

        await store.send(.rotateCandidate(id)) {
            $0.candidates[0].isRotating = true
        }
        await store.receive(\.rotationFinished) {
            $0.candidates[0].pngData = Data([2])
            $0.candidates[0].isRotating = false
        }
    }

    @MainActor
    func test_saveTapped_persistsSelectedCutouts() async {
        let savedMeal = MealSnapshot(id: UUID(), eatenAt: Date(), place: nil,
                                     memo: "맛있다", rating: 5, cutouts: [])
        let store = TestStore(
            initialState: CaptureFeature.State(
                candidates: [
                    .init(id: UUID(), pngData: Data([1]), isSelected: true),
                    .init(id: UUID(), pngData: Data([2]), isSelected: false),
                ],
                memo: "맛있다",
                rating: 5
            )
        ) {
            CaptureFeature()
        } withDependencies: {
            $0.persistence.saveMeal = { _, memo, rating, cutouts in
                XCTAssertEqual(cutouts.count, 1) // only the selected one
                XCTAssertEqual(cutouts.first?.label, "heart")
                XCTAssertEqual(memo, "맛있다")
                XCTAssertEqual(rating, 5)
                return savedMeal
            }
        }

        await store.send(.cycleDecoration(store.state.candidates[0].id)) {
            $0.candidates[0].decoration = .sparkle
        }
        await store.send(.cycleDecoration(store.state.candidates[0].id)) {
            $0.candidates[0].decoration = .heart
        }
        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(\.saved) {
            $0 = CaptureFeature.State()
            $0.savedMeal = savedMeal
        }
    }

    @MainActor
    func test_placeSelected_dismissesPickerAndKeepsChosenPlace() async {
        let place = PlaceInfo(id: "1", name: "라멘집", address: "후쿠오카")
        let savedMeal = MealSnapshot(id: UUID(), eatenAt: Date(), place: place,
                                     memo: "", rating: nil, cutouts: [])
        let store = TestStore(initialState: CaptureFeature.State()) {
            CaptureFeature()
        } withDependencies: {
            $0.persistence.saveMeal = { chosenPlace, _, _, _ in
                XCTAssertEqual(chosenPlace, place)
                return savedMeal
            }
        }

        await store.send(.choosePlaceTapped) {
            $0.placePicker = PlacePickerFeature.State()
        }
        // The child reducer sets `selected` first, then CaptureFeature's own
        // case intercepts it: copies it to `chosenPlace` and dismisses the sheet.
        await store.send(.placePicker(.presented(.placeSelected(place)))) {
            $0.chosenPlace = place
            $0.placePicker = nil
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(\.saved) {
            $0 = CaptureFeature.State()
            $0.savedMeal = savedMeal
        }
    }
}
