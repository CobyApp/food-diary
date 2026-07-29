import ComposableArchitecture
import Models
import XCTest
@testable import FeatureKit

final class RecapFeatureTests: XCTestCase {
    /// The recap shows the board it was handed. There is no query and no range,
    /// so the count is simply how many stickers came in.
    @MainActor
    func test_recapShowsExactlyTheBoardItWasGiven() async {
        let onBoard = [
            FoodEntrySnapshot(id: UUID(), fileName: "a.png", eatenAt: Date()),
            FoodEntrySnapshot(id: UUID(), fileName: "b.png", eatenAt: Date()),
        ]
        let store = TestStore(initialState: RecapFeature.State(cutouts: onBoard)) {
            RecapFeature()
        } withDependencies: {
            $0.locale = Locale(identifier: "ko_KR")
            $0.caption.weeklyCaption = { _, _, _ in nil }
        }

        XCTAssertEqual(store.state.mealCount, 2)
        await store.send(.onAppear)
        // No change to assert: an unavailable model leaves the line nil, which is
        // what it already was.
        await store.receive(\.captionGenerated)
    }

    /// Nothing on the board means nothing to caption, so no request is made.
    @MainActor
    func test_anEmptyBoardAsksForNoCaption() async {
        let store = TestStore(initialState: RecapFeature.State()) {
            RecapFeature()
        }

        XCTAssertEqual(store.state.mealCount, 0)
        await store.send(.onAppear)
    }
}
