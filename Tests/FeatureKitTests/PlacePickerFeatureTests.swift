import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class PlacePickerFeatureTests: XCTestCase {
    @MainActor
    func test_task_loadsNearbyPlaces() async {
        let places = [PlaceInfo(id: "1", name: "라멘집", address: "후쿠오카")]
        let store = TestStore(
            initialState: PlacePickerFeature.State(coordinate: Coordinate(latitude: 1, longitude: 2))
        ) {
            PlacePickerFeature()
        } withDependencies: {
            $0.placeSearch.nearby = { _ in places }
        }

        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.placesLoaded) {
            $0.isLoading = false
            $0.places = places
        }
    }

    @MainActor
    func test_manualEntry_setsSelected() async {
        let store = TestStore(initialState: PlacePickerFeature.State()) {
            PlacePickerFeature()
        }
        await store.send(.manualNameChanged("우리집")) { $0.manualName = "우리집" }
        await store.send(.useManualEntry) {
            $0.selected = PlaceInfo(id: "manual", name: "우리집", address: "")
        }
    }

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
}
