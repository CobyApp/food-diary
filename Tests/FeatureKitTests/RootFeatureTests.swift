import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class RootFeatureTests: XCTestCase {
    @MainActor
    func test_cutoutTapped_pushesMealDetail() async {
        let mealID = UUID()
        let cutoutID = UUID()
        let meal = MealSnapshot(id: mealID, eatenAt: Date(), place: nil, memo: "", rating: nil, cutouts: [])
        let store = TestStore(initialState: RootFeature.State()) {
            RootFeature()
        } withDependencies: {
            $0.persistence.mealByCutout = { _ in meal }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.collection(.cutoutTapped(cutoutID)))
        // NB: intentionally not asserting the exact `StackState` mutation via a
        // `$0.path.append(...)` closure here. TCA's TestStore only snapshots/restores
        // the `stackElementID` generator around directly-*sent* actions (see
        // TestStore.send's `previousStackElementID` dance); it does not do the same
        // for actions delivered by an in-flight effect (`.receive`). Since `pushDetail`
        // arrives via `.run`, the real reducer's `path.append` and this closure's
        // `path.append` would draw different auto-assigned StackElementIDs, causing a
        // spurious mismatch unrelated to the actual behavior under test. Assert the
        // resulting content directly instead.
        await store.receive(\.pushDetail)
        XCTAssertEqual(store.state.path.map(\.mealID), [mealID])
    }

    @MainActor
    func test_tabChanged_updatesTab() async {
        let store = TestStore(initialState: RootFeature.State()) { RootFeature() }
        await store.send(.tabChanged(.capture)) { $0.tab = .capture }
    }
}
