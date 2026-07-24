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
                XCTAssertEqual(memo, "맛있다")
                XCTAssertEqual(rating, 5)
                return savedMeal
            }
        }

        await store.send(.saveTapped)
        await store.receive(\.saved) { $0.savedMeal = savedMeal }
    }
}
