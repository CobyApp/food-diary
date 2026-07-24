import XCTest
import SwiftData
import Models
@testable import ClientKit

final class PersistenceClientTests: XCTestCase {
    func test_saveMeal_thenAllCutouts_roundTrips() async throws {
        let container = try ModelContainer(
            for: Meal.self, FoodCutout.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        var savedNames: [String] = []
        let store = ImageStore(
            save: { _ in let n = "\(savedNames.count).png"; savedNames.append(n); return n },
            load: { _ in nil },
            delete: { _ in }
        )
        let client = PersistenceClient.live(container: container, imageStore: store)

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
}
