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
                         tags: ["다시 먹고 싶다"], rating: 5, cutouts: [])
        ]
        let store = TestStore(initialState: AchievementsFeature.State()) {
            AchievementsFeature()
        } withDependencies: {
            $0.persistence.allCutouts = { cutouts }
            $0.persistence.allMeals = { meals }
        }

        await store.send(.onAppear)
        await store.receive(\.statsLoaded) {
            $0.stats.cutouts = 10
            $0.stats.meals = 1
            $0.stats.places = 1
            $0.stats.bestStreak = 1
            $0.stats.ratedMeals = 1
            $0.stats.fiveStarMeals = 1
        }
        let a = store.state.achievements
        // 89 since the one-line-review series went away with the review itself.
        XCTAssertEqual(a.count, 89)
        XCTAssertEqual(Set(a.map(\.id)).count, 89)
        XCTAssertTrue(a.first { $0.id == "cut1" }!.unlocked)
        XCTAssertTrue(a.first { $0.id == "cut10" }!.unlocked)
        XCTAssertFalse(a.first { $0.id == "cut50" }!.unlocked)
        XCTAssertTrue(a.first { $0.id == "plc1" }!.unlocked)
        XCTAssertFalse(a.first { $0.id == "plc5" }!.unlocked)
        XCTAssertTrue(a.first { $0.id == "rating1" }!.unlocked)
        XCTAssertTrue(a.first { $0.id == "five1" }!.unlocked)
        XCTAssertFalse(a.first { $0.id == "streak3" }!.unlocked)
    }
}
