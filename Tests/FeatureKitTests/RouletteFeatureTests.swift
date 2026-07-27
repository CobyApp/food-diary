import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class RouletteFeatureTests: XCTestCase {
    private func snap(_ n: Int) -> CutoutSnapshot {
        CutoutSnapshot(id: UUID(), fileName: "\(n).png", createdAt: Date(), label: "f\(n)")
    }

    @MainActor
    func test_spin_setsPickedResult() async {
        let items = [snap(1), snap(2)]
        let picked = items[0]
        let store = TestStore(initialState: RouletteFeature.State(cutouts: items)) {
            RouletteFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.random.pick = { _ in picked }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.spin) {
            $0.isSpinning = true
            $0.result = picked
            $0.lastResultID = picked.id
        }
    }

    @MainActor
    func test_spin_placesWinnerAtLandingIndex() async {
        let items = [snap(1), snap(2), snap(3)]
        let picked = items[2]
        let store = TestStore(initialState: RouletteFeature.State(cutouts: items)) {
            RouletteFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 }
            $0.random.pick = { _ in picked }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.spin)
        XCTAssertEqual(store.state.result?.id, picked.id)
        XCTAssertEqual(store.state.reel.last?.id, picked.id)
        XCTAssertEqual(store.state.landingIndex, store.state.reel.count - 1)
    }
}
