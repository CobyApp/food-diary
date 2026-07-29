import XCTest
import SwiftData
import Models
@testable import ClientKit

final class PersistenceClientTests: XCTestCase {
    // Fresh in-memory client per test. UUID-named files avoid any shared
    // mutable state in the stub (Swift 6 @Sendable-safe).
    private func makeClient() throws -> PersistenceClient {
        let container = try ModelContainer(
            for: FoodEntry.self, FoodTag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ImageStore(
            save: { _ in "\(UUID().uuidString).png" },
            load: { _ in nil },
            delete: { _ in }
        )
        return PersistenceClient.live(container: container, imageStore: store)
    }

    func test_saveEntries_thenAllEntries_roundTrips() async throws {
        let client = try makeClient()
        let place = PlaceInfo(id: "p1", name: "라멘집", address: "후쿠오카")

        let saved = try await client.saveEntries(
            place,
            [
                NewEntry(pngData: Data([1]), label: "라멘", tags: ["맛있다"], rating: 5),
                NewEntry(pngData: Data([2]), label: "교자", tags: ["바삭"], rating: 4),
            ]
        )

        XCTAssertEqual(saved.count, 2)
        let all = try await client.allEntries()
        XCTAssertEqual(all.count, 2)
        let ramen = all.first { $0.label == "라멘" }
        XCTAssertEqual(ramen?.tags, ["맛있다"])
        XCTAssertEqual(ramen?.rating, 5)
        XCTAssertEqual(ramen?.place?.name, "라멘집")
    }

    func test_allEntries_returnsNewestFirst() async throws {
        let client = try makeClient()
        // Two sequential (awaited) saves guarantee distinct timestamps.
        _ = try await client.saveEntries(nil, [NewEntry(pngData: Data([1]), label: "older")])
        _ = try await client.saveEntries(nil, [NewEntry(pngData: Data([2]), label: "newer")])

        let all = try await client.allEntries()
        XCTAssertEqual(all.first?.label, "newer")
    }

    func test_entry_findsASavedFoodByID() async throws {
        let client = try makeClient()
        let saved = try await client.saveEntries(nil, [NewEntry(pngData: Data([1]), label: "라멘")])
        let id = try XCTUnwrap(saved.first?.id)

        let found = try await client.entry(id)
        XCTAssertEqual(found?.label, "라멘")
    }

    func test_entry_isNilForAnUnknownID() async throws {
        let client = try makeClient()
        let found = try await client.entry(UUID())
        XCTAssertNil(found)
    }

    func test_deleteEntries_removesOnlyWhatWasAsked() async throws {
        let client = try makeClient()
        let saved = try await client.saveEntries(
            nil,
            [
                NewEntry(pngData: Data([1]), label: "keep"),
                NewEntry(pngData: Data([2]), label: "drop"),
            ]
        )
        let doomed = try XCTUnwrap(saved.first { $0.label == "drop" })

        try await client.deleteEntries([doomed.id])

        let all = try await client.allEntries()
        XCTAssertEqual(all.map(\.label), ["keep"])
    }

    func test_deleteEntries_alsoRemovesTheImageFile() async throws {
        let container = try ModelContainer(
            for: FoodEntry.self, FoodTag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let deleted = LockBox<[String]>([])
        let store = ImageStore(
            save: { _ in "image.png" },
            load: { _ in nil },
            delete: { name in deleted.append(name) }
        )
        let client = PersistenceClient.live(container: container, imageStore: store)
        let saved = try await client.saveEntries(nil, [NewEntry(pngData: Data([1]))])

        try await client.deleteEntries([try XCTUnwrap(saved.first?.id)])

        XCTAssertEqual(deleted.value, ["image.png"])
    }

    /// A failure partway through a batch must not leave written PNGs behind.
    func test_saveEntries_whenAnImageWriteFails_rollsBackWrittenImages() async throws {
        struct WriteFailure: Error {}
        let container = try ModelContainer(
            for: FoodEntry.self, FoodTag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let deleted = LockBox<[String]>([])
        let attempt = Counter()
        let store = ImageStore(
            save: { _ in
                let current = attempt.next()
                if current == 2 { throw WriteFailure() }
                return "written-\(current).png"
            },
            load: { _ in nil },
            delete: { name in deleted.append(name) }
        )
        let client = PersistenceClient.live(container: container, imageStore: store)

        do {
            _ = try await client.saveEntries(
                nil,
                [NewEntry(pngData: Data([1])), NewEntry(pngData: Data([2]))]
            )
            XCTFail("save should have thrown")
        } catch {
            // expected
        }

        XCTAssertEqual(deleted.value, ["written-1.png"])
        let all = try await client.allEntries()
        XCTAssertTrue(all.isEmpty)
    }
}

/// ConcurrencyExtras' LockIsolated isn't linked into this target.
private final class LockBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) { stored = value }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func append(_ element: Value.Element) where Value: RangeReplaceableCollection {
        lock.lock()
        defer { lock.unlock() }
        stored.append(element)
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }
}
