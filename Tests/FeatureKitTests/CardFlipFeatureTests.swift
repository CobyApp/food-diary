import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class CardFlipFeatureTests: XCTestCase {
    private func snap(_ n: Int) -> CutoutSnapshot {
        CutoutSnapshot(id: UUID(), fileName: "\(n).png", createdAt: Date(), label: "f\(n)")
    }

    @MainActor
    func test_start_laysCards_flipSelectsCard() async {
        let items = [snap(1), snap(2), snap(3)]
        let store = TestStore(initialState: CardFlipFeature.State(cutouts: items)) {
            CardFlipFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.start) { $0.cards = items }
        await store.send(.flip(1)) { $0.revealedIndex = 1 }
        // result computed property returns cards[1]
        XCTAssertEqual(store.state.result?.id, items[1].id)
    }
}
