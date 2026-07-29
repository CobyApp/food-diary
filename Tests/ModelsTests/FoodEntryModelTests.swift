import XCTest
import SwiftData
@testable import Models

final class FoodEntryModelTests: XCTestCase {
    @MainActor
    func test_entry_persistsAndSnapshots() throws {
        let container = try ModelContainer(
            for: FoodEntry.self, FoodTag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let entry = FoodEntry(
            fileName: "a.png",
            eatenAt: Date(timeIntervalSince1970: 1_000_000),
            label: "라멘",
            tags: ["맛있었다"],
            rating: 4
        )
        entry.place = PlaceInfo(id: "p1", name: "라멘집", address: "후쿠오카")
        context.insert(entry)
        try context.save()

        let snap = entry.snapshot()
        XCTAssertEqual(snap.fileName, "a.png")
        XCTAssertEqual(snap.label, "라멘")
        XCTAssertEqual(snap.tags, ["맛있었다"])
        XCTAssertEqual(snap.rating, 4)
        XCTAssertEqual(snap.place?.name, "라멘집")
    }

    /// The place round-trips through JSON, so it has to survive a save/reload.
    func test_placeSurvivesEncoding() {
        let entry = FoodEntry(fileName: "b.png")
        XCTAssertNil(entry.place)
        entry.place = PlaceInfo(id: "p2", name: "우동집", address: "하카타")
        XCTAssertEqual(entry.place?.name, "우동집")
        entry.place = nil
        XCTAssertNil(entry.placeData)
    }
}
