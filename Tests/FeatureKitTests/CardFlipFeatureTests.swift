import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class CardFlipFeatureTests: XCTestCase {
    private func snap(_ n: Int) -> CutoutSnapshot {
        CutoutSnapshot(id: UUID(), fileName: "\(n).png", createdAt: Date(), label: "f\(n)")
    }

    @MainActor
    func test_start_laysPairs_andMatchingPairSelectsResult() async {
        let items = [snap(1), snap(2), snap(3)]
        let store = TestStore(initialState: CardFlipFeature.State(cutouts: items)) {
            CardFlipFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.start) {
            $0.cards = items + items
        }
        await store.send(.flip(1)) {
            $0.firstRevealedIndex = 1
        }
        await store.send(.flip(4)) {
            $0.secondRevealedIndex = 4
            $0.moves = 1
            $0.result = items[1]
        }
        XCTAssertEqual(store.state.result?.id, items[1].id)
    }

    @MainActor
    func test_mismatchHidesBothCards() async {
        let items = [snap(1), snap(2), snap(3)]
        let store = TestStore(initialState: CardFlipFeature.State(cutouts: items)) {
            CardFlipFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
        }

        await store.send(.start) { $0.cards = items + items }
        await store.send(.flip(0)) { $0.firstRevealedIndex = 0 }
        await store.send(.flip(1)) {
            $0.secondRevealedIndex = 1
            $0.moves = 1
        }
        await store.send(.hideMismatch) {
            $0.firstRevealedIndex = nil
            $0.secondRevealedIndex = nil
        }
    }
}
