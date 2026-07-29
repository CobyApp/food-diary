import XCTest
import SwiftData
import Models
@testable import ClientKit

/// The tag catalog and the tag names stored on each food have to stay in step:
/// foods hold names, not references, so every rename and delete has to reach
/// into them.
final class TagCatalogTests: XCTestCase {
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

    private func entry(_ tags: [String] = []) -> NewEntry {
        NewEntry(pngData: Data([1]), label: nil, tags: tags)
    }

    // MARK: - Creating

    func test_createdTagsComeBackAlphabetically() async throws {
        let client = try makeClient()
        try await client.createTag("우동")
        try await client.createTag("라멘")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, ["라멘", "우동"])
    }

    func test_createTagNormalizesWhatWasTyped() async throws {
        let client = try makeClient()
        try await client.createTag("  #매운   라멘 ")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, ["매운 라멘"])
    }

    func test_createTagIgnoresATagThatAlreadyExists() async throws {
        let client = try makeClient()
        try await client.createTag("라멘")
        try await client.createTag(" 라멘 ")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, ["라멘"])
    }

    func test_createTagIgnoresBlankInput() async throws {
        let client = try makeClient()
        try await client.createTag("   ")
        try await client.createTag("#")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, [])
    }

    // MARK: - Saving

    func test_savedFoodKeepsPickOrderAndDropsRepeats() async throws {
        let client = try makeClient()
        let saved = try await client.saveEntries(nil, [entry(["라멘", " 라멘 ", "우동"])])

        XCTAssertEqual(saved.first?.tags, ["라멘", "우동"])
    }

    /// The whole point of the rewrite: several foods saved together each keep
    /// their own tags instead of sharing one set.
    func test_eachFoodSavedTogetherKeepsItsOwnTags() async throws {
        let client = try makeClient()
        let saved = try await client.saveEntries(
            PlaceInfo(id: "p", name: "라멘집", address: "후쿠오카"),
            [entry(["라멘"]), entry(["교자"])]
        )

        XCTAssertEqual(saved.count, 2)
        XCTAssertEqual(Set(saved.flatMap(\.tags)), ["라멘", "교자"])
        // The place is shared: it describes the sitting, not the dish.
        XCTAssertEqual(Set(saved.compactMap { $0.place?.name }), ["라멘집"])
    }

    // MARK: - Renaming

    func test_renameUpdatesTheCatalogAndEveryFoodUsingIt() async throws {
        let client = try makeClient()
        try await client.createTag("라멘")
        _ = try await client.saveEntries(nil, [entry(["라멘", "우동"]), entry(["우동"])])

        try await client.renameTag("라멘", "돈코츠")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, ["돈코츠"])
        let entries = try await client.allEntries()
        XCTAssertTrue(entries.contains { $0.tags.contains("돈코츠") })
        XCTAssertFalse(entries.contains { $0.tags.contains("라멘") })
        // The food that never had the tag is untouched.
        XCTAssertTrue(entries.contains { $0.tags == ["우동"] })
    }

    /// Renaming onto a name that already exists must not leave a food carrying
    /// the same tag twice, or the catalog holding a duplicate.
    func test_renameOntoAnExistingTagMergesInsteadOfDuplicating() async throws {
        let client = try makeClient()
        try await client.createTag("라멘")
        try await client.createTag("우동")
        _ = try await client.saveEntries(nil, [entry(["라멘", "우동"])])

        try await client.renameTag("라멘", "우동")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, ["우동"])
        let entries = try await client.allEntries()
        XCTAssertEqual(entries.first?.tags, ["우동"])
    }

    func test_renameIgnoresBlankNewNames() async throws {
        let client = try makeClient()
        try await client.createTag("라멘")

        try await client.renameTag("라멘", "   ")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, ["라멘"])
    }

    func test_renameOfAnUnknownTagChangesNothing() async throws {
        let client = try makeClient()
        try await client.createTag("라멘")

        try await client.renameTag("없는태그", "우동")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, ["라멘"])
    }

    // MARK: - Deleting

    func test_deleteRemovesTheTagFromTheCatalogAndFromFoods() async throws {
        let client = try makeClient()
        try await client.createTag("라멘")
        try await client.createTag("우동")
        _ = try await client.saveEntries(nil, [entry(["라멘", "우동"])])

        try await client.deleteTag("라멘")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, ["우동"])
        let entries = try await client.allEntries()
        XCTAssertEqual(entries.first?.tags, ["우동"])
    }

    func test_deleteMatchesRegardlessOfCase() async throws {
        let client = try makeClient()
        try await client.createTag("Ramen")
        _ = try await client.saveEntries(nil, [entry(["Ramen"])])

        try await client.deleteTag("ramen")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, [])
        let entries = try await client.allEntries()
        XCTAssertEqual(entries.first?.tags, [])
    }

    func test_deletingATagLeavesTheFoodItself() async throws {
        let client = try makeClient()
        _ = try await client.saveEntries(nil, [entry(["라멘"])])

        try await client.deleteTag("라멘")

        let entries = try await client.allEntries()
        XCTAssertEqual(entries.count, 1)
    }
}
