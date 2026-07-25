import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class WorldCupFeatureTests: XCTestCase {
    private func snap(_ n: Int) -> CutoutSnapshot {
        CutoutSnapshot(id: UUID(), fileName: "\(n).png", createdAt: Date(), label: "f\(n)")
    }

    @MainActor
    func test_twoContenders_pickYieldsChampion() async {
        let items = [snap(1), snap(2), snap(3)] // bracket size 2
        let store = TestStore(initialState: WorldCupFeature.State(cutouts: items)) {
            WorldCupFeature()
        } withDependencies: {
            $0.random.shuffled = { $0 } // deterministic order
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.start) {
            $0.currentRound = [items[0], items[1]]
            $0.pairIndex = 0
        }
        await store.send(.pick(items[0])) {
            $0.champion = items[0]
        }
    }
}
