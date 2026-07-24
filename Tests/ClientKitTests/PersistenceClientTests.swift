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
}
