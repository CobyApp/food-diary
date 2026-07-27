import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class RootFeatureTests: XCTestCase {
    @MainActor
    func test_cutoutTapped_flipsInChild_doesNotPush() async {
        let cutoutID = UUID()
        let store = TestStore(initialState: RootFeature.State()) {
            RootFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.collection(.cutoutTapped(cutoutID)))
        XCTAssertEqual(store.state.collection.flippedCutoutID, cutoutID)
        XCTAssertTrue(store.state.path.isEmpty)
    }

    @MainActor
    func test_tabChanged_updatesTab() async {
        let store = TestStore(initialState: RootFeature.State()) { RootFeature() }
        await store.send(.tabChanged(.capture)) { $0.tab = .capture }
    }
}
