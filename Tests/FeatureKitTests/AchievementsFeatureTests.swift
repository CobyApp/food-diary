import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class AchievementsFeatureTests: XCTestCase {
    @MainActor
    func test_onAppear_loadsStats_andComputesUnlocks() async {
        let cutouts = (0..<10).map {
            CutoutSnapshot(id: UUID(), fileName: "\($0).png", createdAt: Date(), label: nil)
        }
        let meals = [
            MealSnapshot(id: UUID(), eatenAt: Date(),
                         place: PlaceInfo(id: "p1", name: "A", address: ""),
                         memo: "", rating: nil, cutouts: [])
        ]
        let store = TestStore(initialState: AchievementsFeature.State()) {
            AchievementsFeature()
        } withDependencies: {
            $0.persistence.allCutouts = { cutouts }
            $0.persistence.allMeals = { meals }
        }

        await store.send(.onAppear)
        await store.receive(\.statsLoaded) {
            $0.cutoutCount = 10
            $0.mealCount = 1
            $0.placeCount = 1
        }
        let a = store.state.achievements
        XCTAssertTrue(a.first { $0.id == "cut1" }!.unlocked)
        XCTAssertTrue(a.first { $0.id == "cut10" }!.unlocked)
        XCTAssertFalse(a.first { $0.id == "cut50" }!.unlocked)
        XCTAssertTrue(a.first { $0.id == "plc1" }!.unlocked)
        XCTAssertFalse(a.first { $0.id == "plc5" }!.unlocked)
    }
}
