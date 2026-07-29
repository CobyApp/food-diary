import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class FoodMapFeatureTests: XCTestCase {
    private func meal(_ name: String, coord: Coordinate?) -> FoodEntrySnapshot {
        FoodEntrySnapshot(
            id: UUID(),
            fileName: "\(name).png",
            eatenAt: Date(),
            place: PlaceInfo(id: name, name: name, address: "", coordinate: coord)
        )
    }

    @MainActor
    func test_onAppear_loadsMeals_pinsFilterByCoordinate_selectAndDismiss() async {
        let withCoord = meal("라멘집", coord: Coordinate(latitude: 35.6, longitude: 139.7))
        let noCoord = meal("집밥", coord: nil)
        let store = TestStore(initialState: FoodMapFeature.State()) {
            FoodMapFeature()
        } withDependencies: {
            $0.persistence.allEntries = { [withCoord, noCoord] }
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
        let firstCutout = FoodEntrySnapshot(
            id: UUID(), fileName: "1.png", eatenAt: Date(), label: nil
        )
        let secondCutout = FoodEntrySnapshot(
            id: UUID(), fileName: "2.png", eatenAt: Date(), label: nil
        )
        let coordinate = Coordinate(latitude: 35.6, longitude: 139.7)
        let firstMeal = FoodEntrySnapshot(
            id: firstCutout.id, fileName: firstCutout.fileName, eatenAt: Date(),
            place: PlaceInfo(id: "a", name: "A", address: "", coordinate: coordinate)
        )
        let secondMeal = FoodEntrySnapshot(
            id: secondCutout.id, fileName: secondCutout.fileName, eatenAt: Date(),
            place: PlaceInfo(id: "b", name: "B", address: "", coordinate: coordinate)
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
