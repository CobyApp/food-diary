import XCTest
import SwiftData
import Models
@testable import ClientKit

/// The tag catalog and the tag names stored on meals have to stay in step:
/// meals hold names, not references, so every rename and delete has to reach
/// into them.
final class TagCatalogTests: XCTestCase {
    private func makeClient() throws -> PersistenceClient {
        let container = try ModelContainer(
            for: Meal.self, FoodCutout.self, FoodTag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = ImageStore(
            save: { _ in "\(UUID().uuidString).png" },
            load: { _ in nil },
            delete: { _ in }
        )
        return PersistenceClient.live(container: container, imageStore: store)
    }

    private func cutout() -> NewCutout {
        NewCutout(pngData: Data([1]), label: nil)
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

    // MARK: - Saving a meal

    func test_savedMealKeepsPickOrderAndDropsRepeats() async throws {
        let client = try makeClient()
        let meal = try await client.saveMeal(nil, ["라멘", " 라멘 ", "우동"], nil, [cutout()])

        XCTAssertEqual(meal.tags, ["라멘", "우동"])
    }

    // MARK: - Renaming

    func test_renameUpdatesTheCatalogAndEveryMealUsingIt() async throws {
        let client = try makeClient()
        try await client.createTag("라멘")
        _ = try await client.saveMeal(nil, ["라멘", "우동"], nil, [cutout()])
        _ = try await client.saveMeal(nil, ["우동"], nil, [cutout()])

        try await client.renameTag("라멘", "돈코츠")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, ["돈코츠"])
        let meals = try await client.allMeals()
        XCTAssertTrue(meals.contains { $0.tags.contains("돈코츠") })
        XCTAssertFalse(meals.contains { $0.tags.contains("라멘") })
        // The meal that never had the tag is untouched.
        XCTAssertTrue(meals.contains { $0.tags == ["우동"] })
    }

    /// Renaming onto a name that already exists must not leave a meal carrying
    /// the same tag twice, or the catalog holding a duplicate.
    func test_renameOntoAnExistingTagMergesInsteadOfDuplicating() async throws {
        let client = try makeClient()
        try await client.createTag("라멘")
        try await client.createTag("우동")
        _ = try await client.saveMeal(nil, ["라멘", "우동"], nil, [cutout()])

        try await client.renameTag("라멘", "우동")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, ["우동"])
        let meals = try await client.allMeals()
        XCTAssertEqual(meals.first?.tags, ["우동"])
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

    func test_deleteRemovesTheTagFromTheCatalogAndFromMeals() async throws {
        let client = try makeClient()
        try await client.createTag("라멘")
        try await client.createTag("우동")
        _ = try await client.saveMeal(nil, ["라멘", "우동"], nil, [cutout()])

        try await client.deleteTag("라멘")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, ["우동"])
        let meals = try await client.allMeals()
        XCTAssertEqual(meals.first?.tags, ["우동"])
    }

    func test_deleteMatchesRegardlessOfCase() async throws {
        let client = try makeClient()
        try await client.createTag("Ramen")
        _ = try await client.saveMeal(nil, ["Ramen"], nil, [cutout()])

        try await client.deleteTag("ramen")

        let tags = try await client.allTags()
        XCTAssertEqual(tags, [])
        let meals = try await client.allMeals()
        XCTAssertEqual(meals.first?.tags, [])
    }

    func test_deletingATagLeavesTheMealItself() async throws {
        let client = try makeClient()
        _ = try await client.saveMeal(nil, ["라멘"], nil, [cutout()])

        try await client.deleteTag("라멘")

        let meals = try await client.allMeals()
        let cutouts = try await client.allCutouts()
        XCTAssertEqual(meals.count, 1)
        XCTAssertEqual(cutouts.count, 1)
    }
}
