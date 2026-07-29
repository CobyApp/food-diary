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
            $0.isProcessing = true
            $0.processingTotal = 1
        }
        await store.receive(\.photoProcessingProgress) {
            $0.processingCompleted = 1
        }
        await store.receive(\.processingFinished) {
            $0.isProcessing = false
            $0.processingCompleted = 0
            $0.processingTotal = 0
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
            $0.isProcessing = true
            $0.processingTotal = 1
        }
        await store.receive(\.photoProcessingProgress) {
            $0.processingCompleted = 1
        }
        await store.receive(\.processingFinished) {
            $0.isProcessing = false
            $0.processingCompleted = 0
            $0.processingTotal = 0
            $0.coordinate = nil
            $0.candidates = []
        }
    }

    @MainActor
    func test_photosPicked_processesBatchAndAppendsAllCutouts() async {
        let existing = CaptureFeature.CutoutCandidate(
            id: UUID(),
            pngData: Data([7])
        )
        let store = TestStore(
            initialState: CaptureFeature.State(candidates: [existing])
        ) {
            CaptureFeature()
        } withDependencies: {
            $0.foodCutout.extract = { data in
                [Cutout(pngData: Data([(data.first ?? 0) + 10]))]
            }
            $0.photoLocation.coordinate = { data in
                data.first == 1 ? Coordinate(latitude: 1, longitude: 2) : nil
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.photosPicked([Data([1]), Data([2])])) {
            $0.isProcessing = true
            $0.processingTotal = 2
        }
        await store.receive(\.photoProcessingProgress) {
            $0.processingCompleted = 1
        }
        await store.receive(\.photoProcessingProgress) {
            $0.processingCompleted = 2
        }
        await store.receive(\.processingFinished) {
            $0.isProcessing = false
            $0.processingCompleted = 0
            $0.processingTotal = 0
            $0.coordinate = Coordinate(latitude: 1, longitude: 2)
            $0.candidates = [
                existing,
                .init(
                    id: $0.candidates[1].id,
                    pngData: Data([11]),
                    isSelected: true
                ),
                .init(
                    id: $0.candidates[2].id,
                    pngData: Data([12]),
                    isSelected: true
                ),
            ]
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

    /// Each selected food becomes its own record, carrying the information that
    /// was filled in for it and nothing from its neighbour.
    @MainActor
    func test_saveTapped_writesOneRecordPerSelectedFood() async {
        let saved = [
            FoodEntrySnapshot(id: UUID(), fileName: "a.png", eatenAt: Date(), tags: ["맛있다"])
        ]
        let store = TestStore(
            initialState: CaptureFeature.State(
                candidates: [
                    .init(id: UUID(), pngData: Data([1]), isSelected: true,
                          tags: ["맛있다"], rating: 5),
                    .init(id: UUID(), pngData: Data([2]), isSelected: false,
                          tags: ["안 고름"], rating: 1),
                ]
            )
        ) {
            CaptureFeature()
        } withDependencies: {
            $0.persistence.saveEntries = { _, entries in
                XCTAssertEqual(entries.count, 1) // only the selected one
                XCTAssertEqual(entries.first?.label, "heart")
                XCTAssertEqual(entries.first?.tags, ["맛있다"])
                XCTAssertEqual(entries.first?.rating, 5)
                return saved
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
            $0.savedEntries = saved
        }
    }

    @MainActor
    func test_placeSelected_dismissesPickerAndKeepsChosenPlace() async {
        let place = PlaceInfo(id: "1", name: "라멘집", address: "후쿠오카")
        let saved = [FoodEntrySnapshot(id: UUID(), fileName: "a.png", eatenAt: Date())]
        let store = TestStore(
            initialState: CaptureFeature.State(
                candidates: [.init(id: UUID(), pngData: Data([1]), isSelected: true)]
            )
        ) {
            CaptureFeature()
        } withDependencies: {
            $0.persistence.saveEntries = { chosenPlace, _ in
                XCTAssertEqual(chosenPlace, place)
                return saved
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
            $0.savedEntries = saved
        }
    }

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
            $0.persistence.saveEntries = { _, _ in throw SaveFailure() }
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
}
