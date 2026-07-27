import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class FoodMapFeatureTests: XCTestCase {
    private func meal(_ name: String, coord: Coordinate?) -> MealSnapshot {
        let cutout = CutoutSnapshot(
            id: UUID(),
            fileName: "\(name).png",
            createdAt: Date(),
            label: nil
        )
        return MealSnapshot(id: UUID(), eatenAt: Date(),
                            place: PlaceInfo(id: name, name: name, address: "", coordinate: coord),
                            memo: "", rating: nil, cutouts: [cutout])
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

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.mealsLoaded) {
            $0.isLoading = false
            $0.meals = [withCoord, noCoord]
        }
        XCTAssertEqual(store.state.pins.map(\.id), [withCoord.id])

        await store.send(.pinTapped(withCoord.id)) { $0.selectedMealID = withCoord.id }
        XCTAssertEqual(store.state.selectedMeal?.id, withCoord.id)
        await store.send(.dismissCard) { $0.selectedMealID = nil }
    }

    @MainActor
    func test_deletedCutouts_removeEmptyPinsImmediately() async {
        let firstCutout = CutoutSnapshot(
            id: UUID(), fileName: "1.png", createdAt: Date(), label: nil
        )
        let secondCutout = CutoutSnapshot(
            id: UUID(), fileName: "2.png", createdAt: Date(), label: nil
        )
        let coordinate = Coordinate(latitude: 35.6, longitude: 139.7)
        let firstMeal = MealSnapshot(
            id: UUID(), eatenAt: Date(),
            place: PlaceInfo(id: "a", name: "A", address: "", coordinate: coordinate),
            memo: "", rating: nil, cutouts: [firstCutout]
        )
        let secondMeal = MealSnapshot(
            id: UUID(), eatenAt: Date(),
            place: PlaceInfo(id: "b", name: "B", address: "", coordinate: coordinate),
            memo: "", rating: nil, cutouts: [secondCutout]
        )
        var state = FoodMapFeature.State()
        state.meals = [firstMeal, secondMeal]
        state.selectedMealID = firstMeal.id
        let store = TestStore(initialState: state) { FoodMapFeature() }

        await store.send(.cutoutsDeleted([firstCutout.id])) {
            $0.meals = [secondMeal]
            $0.selectedMealID = nil
        }
        XCTAssertEqual(store.state.pins.map(\.id), [secondMeal.id])
    }
}
