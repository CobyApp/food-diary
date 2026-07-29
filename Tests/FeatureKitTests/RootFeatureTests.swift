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
        XCTAssertEqual(store.state.collection.selectedCutoutID, cutoutID)
        XCTAssertTrue(store.state.path.isEmpty)
    }

    /// Arriving on a tab is what reloads it, now that the board has no pull
    /// gesture and does not scroll.
    @MainActor
    func test_tabChanged_updatesTabAndReloadsIt() async {
        let store = TestStore(initialState: RootFeature.State()) {
            RootFeature()
        } withDependencies: {
            $0.persistence.allTags = { [] }
            $0.persistence.allEntries = { [] }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tabChanged(.capture)) { $0.tab = .capture }
        await store.receive(\.capture.tagsOnAppear)

        await store.send(.tabChanged(.collection)) { $0.tab = .collection }
        await store.receive(\.collection.onAppear)
        await store.receive(\.collection.streakOnAppear)
    }
}
