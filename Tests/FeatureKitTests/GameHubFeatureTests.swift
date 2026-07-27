import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class GameHubFeatureTests: XCTestCase {
    private func snap(_ n: Int) -> CutoutSnapshot {
        CutoutSnapshot(id: UUID(), fileName: "\(n).png", createdAt: Date(), label: "f\(n)")
    }

    @MainActor
    func test_onAppear_loadsCutouts() async {
        let items = [snap(1), snap(2), snap(3)]
        let store = TestStore(initialState: GameHubFeature.State()) {
            GameHubFeature()
        } withDependencies: {
            $0.persistence.allCutouts = { items }
        }
        await store.send(.onAppear)
        await store.receive(\.cutoutsLoaded) { $0.cutouts = items }
    }

    @MainActor
    func test_gameTapped_presentsGachaWithPool() async {
        let items = [snap(1), snap(2), snap(3)]
        let store = TestStore(initialState: GameHubFeature.State(cutouts: items)) {
            GameHubFeature()
        }
        await store.send(.gameTapped(.gacha)) {
            $0.game = .gacha(GachaFeature.State(cutouts: items))
        }
    }

    @MainActor
    func test_gameClose_dismisses() async {
        let items = [snap(1)]
        let store = TestStore(
            initialState: GameHubFeature.State(cutouts: items,
                                               game: .gacha(GachaFeature.State(cutouts: items)))
        ) {
            GameHubFeature()
        }
        await store.send(.game(.presented(.gacha(.close)))) {
            $0.game = nil
        }
    }

    @MainActor
    func test_groupTapped_presentsGroupDecider() async {
        let store = TestStore(initialState: GameHubFeature.State()) {
            GameHubFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.groupTapped) {
            $0.groupDecider = GroupDeciderFeature.State()
        }
    }
}
