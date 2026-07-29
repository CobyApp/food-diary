import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

/// Tags are picked and managed on the capture screen itself, so the reducer owns
/// both the meal's picks and the catalog they come from.
@MainActor
final class CaptureTagsTests: XCTestCase {

    func test_onAppear_loadsTheCatalog() async {
        let store = TestStore(initialState: CaptureFeature.State()) {
            CaptureFeature()
        } withDependencies: {
            $0.persistence.allTags = { ["라멘", "카페"] }
        }

        await store.send(.tagsOnAppear)
        await store.receive(\.tagCatalogLoaded) {
            $0.tagCatalog = ["라멘", "카페"]
        }
    }

    func test_tappingATagPicksItAndTappingAgainDropsIt() async {
        let store = TestStore(initialState: CaptureFeature.State()) {
            CaptureFeature()
        }

        await store.send(.tagToggled("라멘")) { $0.tags = ["라멘"] }
        await store.send(.tagToggled("우동")) { $0.tags = ["라멘", "우동"] }
        await store.send(.tagToggled("라멘")) { $0.tags = ["우동"] }
    }

    /// Case is not a difference, so tapping the same tag spelled differently must
    /// unpick it rather than add a second copy.
    func test_pickingIsCaseInsensitive() async {
        let store = TestStore(initialState: CaptureFeature.State(tags: ["Ramen"])) {
            CaptureFeature()
        }

        await store.send(.tagToggled("ramen")) { $0.tags = [] }
    }

    func test_newTagIsSavedToTheCatalogAndPickedStraightAway() async {
        let created = LockBox<[String]>([])
        let store = TestStore(initialState: CaptureFeature.State()) {
            CaptureFeature()
        } withDependencies: {
            $0.persistence.createTag = { created.append($0) }
            $0.persistence.allTags = { ["매운 라멘"] }
        }

        await store.send(.newTagTextChanged("  #매운   라멘 ")) {
            $0.newTagText = "  #매운   라멘 "
        }
        await store.send(.newTagSubmitted) {
            $0.newTagText = ""
            $0.tags = ["매운 라멘"]
        }
        await store.receive(\.tagCatalogLoaded) {
            $0.tagCatalog = ["매운 라멘"]
        }
        XCTAssertEqual(created.value, ["매운 라멘"])
    }

    func test_blankNewTagIsJustCleared() async {
        let store = TestStore(initialState: CaptureFeature.State()) {
            CaptureFeature()
        }

        await store.send(.newTagTextChanged("   ")) { $0.newTagText = "   " }
        await store.send(.newTagSubmitted) { $0.newTagText = "" }
    }

    func test_renamingATagAlsoRenamesThisMealsPick() async {
        let renamed = LockBox<[String]>([])
        let store = TestStore(initialState: CaptureFeature.State(tags: ["라멘", "우동"])) {
            CaptureFeature()
        } withDependencies: {
            $0.persistence.renameTag = { from, to in renamed.append("\(from)->\(to)") }
            $0.persistence.allTags = { ["돈코츠", "우동"] }
        }

        await store.send(.renameTagRequested("라멘")) {
            $0.renamingTag = "라멘"
            $0.renameText = "라멘"
        }
        await store.send(.renameTextChanged("돈코츠")) { $0.renameText = "돈코츠" }
        await store.send(.renameConfirmed) {
            $0.renamingTag = nil
            $0.tags = ["돈코츠", "우동"]
        }
        await store.receive(\.tagCatalogLoaded) {
            $0.tagCatalog = ["돈코츠", "우동"]
        }
        XCTAssertEqual(renamed.value, ["라멘->돈코츠"])
    }

    func test_renamingToTheSameNameDoesNothing() async {
        let store = TestStore(initialState: CaptureFeature.State(tags: ["라멘"])) {
            CaptureFeature()
        }

        await store.send(.renameTagRequested("라멘")) {
            $0.renamingTag = "라멘"
            $0.renameText = "라멘"
        }
        await store.send(.renameConfirmed) { $0.renamingTag = nil }
    }

    func test_deletingATagDropsItFromThisMealToo() async {
        let deleted = LockBox<[String]>([])
        let store = TestStore(initialState: CaptureFeature.State(tags: ["라멘", "우동"])) {
            CaptureFeature()
        } withDependencies: {
            $0.persistence.deleteTag = { deleted.append($0) }
            $0.persistence.allTags = { ["우동"] }
        }

        await store.send(.deleteTagRequested("라멘")) { $0.tags = ["우동"] }
        await store.receive(\.tagCatalogLoaded) { $0.tagCatalog = ["우동"] }
        XCTAssertEqual(deleted.value, ["라멘"])
    }

    /// The catalog belongs to the user, not to one meal, so saving must not wipe it.
    func test_savingKeepsTheCatalogButClearsThePicks() async {
        var state = CaptureFeature.State(tags: ["라멘"])
        state.tagCatalog = ["라멘", "우동"]
        let store = TestStore(initialState: state) { CaptureFeature() }
        let meal = MealSnapshot(
            id: UUID(), eatenAt: Date(), place: nil, tags: ["라멘"], rating: nil, cutouts: []
        )

        await store.send(.saved(meal)) {
            $0.tags = []
            $0.tagCatalog = ["라멘", "우동"]
            $0.savedMeal = meal
        }
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
