import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class GachaFeatureTests: XCTestCase {
    private func snap(_ n: Int) -> CutoutSnapshot {
        CutoutSnapshot(id: UUID(), fileName: "\(n).png", createdAt: Date(), label: "food\(n)")
    }

    @MainActor
    func test_pullLever_revealsPickedCutout_andLoadsPlace() async {
        let items = [snap(1), snap(2)]
        let picked = items[1]
        let store = TestStore(initialState: GachaFeature.State(cutouts: items)) {
            GachaFeature()
        } withDependencies: {
            $0.random.pick = { _ in picked }
            $0.persistence.mealByCutout = { _ in
                MealSnapshot(id: UUID(), eatenAt: Date(),
                             place: PlaceInfo(id: "p", name: "라멘집", address: ""),
                             memo: "", rating: nil, cutouts: [])
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pullLever) {
            $0.isSpinning = true
            $0.result = picked
            $0.drawnIDs = [picked.id]
        }
        await store.receive(\.infoLoaded)
        XCTAssertEqual(store.state.resultInfo?.placeName, "라멘집")
    }

    @MainActor
    func test_playAgainDoesNotRepeatUntilPoolIsUsed() async {
        let items = [snap(1), snap(2), snap(3)]
        let store = TestStore(initialState: GachaFeature.State(cutouts: items)) {
            GachaFeature()
        } withDependencies: {
            $0.random.pick = { $0.first }
            $0.persistence.mealByCutout = { _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pullLever)
        await store.receive(\.infoLoaded)
        let firstID = store.state.result?.id
        await store.send(.playAgain)
        await store.send(.pullLever)
        await store.receive(\.infoLoaded)

        XCTAssertNotEqual(store.state.result?.id, firstID)
    }
}
