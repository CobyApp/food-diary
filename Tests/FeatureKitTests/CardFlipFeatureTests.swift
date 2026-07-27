import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class CardFlipFeatureTests: XCTestCase {
    private func snap(_ n: Int) -> CutoutSnapshot {
        CutoutSnapshot(id: UUID(), fileName: "\(n).png", createdAt: Date(), label: "f\(n)")
    }

    @MainActor
    func test_start_laysDistinctCards() async {
        let items = [snap(1), snap(2), snap(3)]
        let store = TestStore(initialState: CardFlipFeature.State(cutouts: items)) {
            CardFlipFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.start) { $0.cards = items }
        XCTAssertEqual(store.state.cards.count, 3)          // distinct, not doubled
        XCTAssertNil(store.state.result)
    }

    @MainActor
    func test_flip_selectsThatCardAsResult() async {
        let items = [snap(1), snap(2), snap(3)]
        let store = TestStore(initialState: CardFlipFeature.State(cutouts: items)) {
            CardFlipFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.start)
        await store.send(.flip(1)) { $0.revealedIndex = 1 }
        XCTAssertEqual(store.state.result?.id, items[1].id)
    }

    @MainActor
    func test_secondFlipIsIgnored() async {
        let items = [snap(1), snap(2), snap(3)]
        let store = TestStore(initialState: CardFlipFeature.State(cutouts: items)) {
            CardFlipFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.start)
        await store.send(.flip(0)) { $0.revealedIndex = 0 }
        await store.send(.flip(2))                          // ignored: already revealed
        XCTAssertEqual(store.state.revealedIndex, 0)
        XCTAssertEqual(store.state.result?.id, items[0].id)
    }
}
