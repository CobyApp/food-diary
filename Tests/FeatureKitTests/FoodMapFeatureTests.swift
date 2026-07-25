import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class FoodMapFeatureTests: XCTestCase {
    private func meal(_ name: String, coord: Coordinate?) -> MealSnapshot {
        MealSnapshot(id: UUID(), eatenAt: Date(),
                     place: PlaceInfo(id: name, name: name, address: "", coordinate: coord),
                     memo: "", rating: nil, cutouts: [])
    }

    @MainActor
    func test_onAppear_loadsMeals_pinsFilterByCoordinate_selectAndDismiss() async {
        let withCoord = meal("라멘집", coord: Coordinate(latitude: 35.6, longitude: 139.7))
        let noCoord = meal("집밥", coord: nil)
        let store = TestStore(initialState: FoodMapFeature.State()) {
            FoodMapFeature()
        } withDependencies: {
            $0.persistence.allMeals = { [withCoord, noCoord] }
        }

        await store.send(.onAppear)
        await store.receive(\.mealsLoaded) { $0.meals = [withCoord, noCoord] }
        XCTAssertEqual(store.state.pins.map(\.id), [withCoord.id])

        await store.send(.pinTapped(withCoord.id)) { $0.selectedMealID = withCoord.id }
        XCTAssertEqual(store.state.selectedMeal?.id, withCoord.id)
        await store.send(.dismissCard) { $0.selectedMealID = nil }
    }
}
