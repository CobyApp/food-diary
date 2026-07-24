import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class MealDetailFeatureTests: XCTestCase {
    @MainActor
    func test_task_loadsMeal() async {
        let id = UUID()
        let meal = MealSnapshot(id: id, eatenAt: Date(), place: nil, memo: "hi", rating: nil, cutouts: [])
        let store = TestStore(initialState: MealDetailFeature.State(mealID: id)) {
            MealDetailFeature()
        } withDependencies: {
            $0.persistence.meal = { _ in meal }
        }
        await store.send(.task)
        await store.receive(\.mealLoaded) { $0.meal = meal }
    }
}
