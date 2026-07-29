import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class MealDetailFeatureTests: XCTestCase {
    @MainActor
    func test_task_loadsTheFood() async {
        let id = UUID()
        let meal = FoodEntrySnapshot(id: id, fileName: "a.png", eatenAt: Date(), tags: ["hi"])
        let store = TestStore(initialState: MealDetailFeature.State(entryID: id)) {
            MealDetailFeature()
        } withDependencies: {
            $0.persistence.entry = { _ in meal }
        }
        await store.send(.task)
        await store.receive(\.entryLoaded) { $0.entry = meal }
    }
}
