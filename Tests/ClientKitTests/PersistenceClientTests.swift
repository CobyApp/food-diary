import XCTest
import SwiftData
import Models
@testable import ClientKit

final class PersistenceClientTests: XCTestCase {
    // Fresh in-memory client per test. UUID-named files avoid any shared
    // mutable state in the stub (Swift 6 @Sendable-safe).
    private func makeClient() throws -> PersistenceClient {
        let container = try ModelContainer(
            for: Meal.self, FoodCutout.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ImageStore(
            save: { _ in "\(UUID().uuidString).png" },
            load: { _ in nil },
            delete: { _ in }
        )
        return PersistenceClient.live(container: container, imageStore: store)
    }

    func test_saveMeal_thenAllCutouts_roundTrips() async throws {
        let client = try makeClient()

        let place = PlaceInfo(id: "p1", name: "라멘집", address: "후쿠오카")
        let snap = try await client.saveMeal(
            place, "맛있다", 5,
            [NewCutout(pngData: Data([1]), label: "라멘"),
             NewCutout(pngData: Data([2]), label: nil)]
        )

        XCTAssertEqual(snap.cutouts.count, 2)
        XCTAssertEqual(snap.place?.name, "라멘집")

        let all = try await client.allCutouts()
        XCTAssertEqual(all.count, 2)

        let fetched = try await client.meal(snap.id)
        XCTAssertEqual(fetched?.memo, "맛있다")
    }

    func test_allCutouts_areNewestFirst() async throws {
        let client = try makeClient()

        // Two sequential (awaited) saves guarantee distinct createdAt values,
        // so the reverse sort is exercised deterministically.
        _ = try await client.saveMeal(nil, "older", nil, [NewCutout(pngData: Data([1]), label: "old")])
        _ = try await client.saveMeal(nil, "newer", nil, [NewCutout(pngData: Data([2]), label: "new")])

        let all = try await client.allCutouts()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all.first?.label, "new", "newest cutout should come first")
        XCTAssertEqual(all.last?.label, "old")
    }

    func test_mealByCutout_returnsOwningMeal() async throws {
        let container = try ModelContainer(
            for: Meal.self, FoodCutout.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ImageStore(save: { _ in "n.png" }, load: { _ in nil }, delete: { _ in })
        let client = PersistenceClient.live(container: container, imageStore: store)
        let snap = try await client.saveMeal(nil, "m", nil, [NewCutout(pngData: Data([1]), label: nil)])
        let cutoutID = snap.cutouts[0].id
        let owning = try await client.mealByCutout(cutoutID)
        XCTAssertEqual(owning?.id, snap.id)
    }

    func test_allMeals_returnsSavedMealsNewestFirst() async throws {
        let client = try makeClient()
        _ = try await client.saveMeal(PlaceInfo(id: "a", name: "A", address: ""), "older", nil,
                                      [NewCutout(pngData: Data([1]), label: nil)])
        _ = try await client.saveMeal(PlaceInfo(id: "b", name: "B", address: ""), "newer", nil,
                                      [NewCutout(pngData: Data([2]), label: nil)])
        let meals = try await client.allMeals()
        XCTAssertEqual(meals.count, 2)
        XCTAssertEqual(meals.first?.memo, "newer")
        XCTAssertEqual(meals.first?.place?.name, "B")
    }

    func test_deleteMeal_removesMealAndItsCutouts() async throws {
        let client = try makeClient()

        let snap = try await client.saveMeal(
            nil, "to delete", nil,
            [NewCutout(pngData: Data([1]), label: nil),
             NewCutout(pngData: Data([2]), label: nil)]
        )

        try await client.deleteMeal(snap.id)

        let fetched = try await client.meal(snap.id)
        XCTAssertNil(fetched)
        let all = try await client.allCutouts()
        XCTAssertTrue(all.isEmpty, "cascade delete should remove the meal's cutouts")
    }

    func test_deleteCutouts_removesOnlySelectedImages() async throws {
        let client = try makeClient()
        let meal = try await client.saveMeal(
            nil, "keep meal", nil,
            [
                NewCutout(pngData: Data([1]), label: "first"),
                NewCutout(pngData: Data([2]), label: "second"),
            ]
        )

        try await client.deleteCutouts([meal.cutouts[0].id])

        let remaining = try await client.allCutouts()
        let remainingMeal = try await client.meal(meal.id)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, meal.cutouts[1].id)
        XCTAssertEqual(remainingMeal?.memo, "keep meal")
    }
}
