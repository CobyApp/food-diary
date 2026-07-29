import XCTest
import SwiftData
@testable import Models

final class MealModelTests: XCTestCase {
    @MainActor
    func test_meal_persistsAndSnapshots() throws {
        let container = try ModelContainer(
            for: Meal.self, FoodCutout.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let meal = Meal(eatenAt: Date(timeIntervalSince1970: 1_000_000), tags: ["맛있었다"], rating: 4)
        meal.place = PlaceInfo(id: "p1", name: "라멘집", address: "후쿠오카")
        let cutout = FoodCutout(fileName: "a.png", label: "라멘")
        cutout.meal = meal
        meal.cutouts.append(cutout)
        context.insert(meal)
        try context.save()

        let snap = meal.snapshot()
        XCTAssertEqual(snap.tags, ["맛있었다"])
        XCTAssertEqual(snap.rating, 4)
        XCTAssertEqual(snap.place?.name, "라멘집")
        XCTAssertEqual(snap.cutouts.map(\.fileName), ["a.png"])
    }
}
