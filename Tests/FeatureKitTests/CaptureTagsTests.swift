import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

/// Tags belong to a single food, not to the batch: several dishes photographed
/// together are described one at a time.
@MainActor
final class CaptureTagsTests: XCTestCase {

    private let ramenID = UUID()
    private let gyozaID = UUID()

    private func stateWithTwoFoods(
        editing: UUID? = nil,
        ramenTags: [String] = [],
        gyozaTags: [String] = []
    ) -> CaptureFeature.State {
        var state = CaptureFeature.State(
            candidates: [
                .init(id: ramenID, pngData: Data([1]), tags: ramenTags),
                .init(id: gyozaID, pngData: Data([2]), tags: gyozaTags),
            ]
        )
        state.editingCandidateID = editing
        return state
    }

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
        let store = TestStore(initialState: stateWithTwoFoods(editing: ramenID)) {
            CaptureFeature()
        }

        await store.send(.tagToggled("라멘")) { $0.candidates[0].tags = ["라멘"] }
        await store.send(.tagToggled("우동")) { $0.candidates[0].tags = ["라멘", "우동"] }
        await store.send(.tagToggled("라멘")) { $0.candidates[0].tags = ["우동"] }
    }

    /// The whole point: tagging one food must not tag the other.
    func test_tagsGoOnlyToTheFoodBeingDescribed() async {
        let store = TestStore(initialState: stateWithTwoFoods(editing: gyozaID)) {
            CaptureFeature()
        }

        await store.send(.tagToggled("교자")) { $0.candidates[1].tags = ["교자"] }
        XCTAssertTrue(store.state.candidates[0].tags.isEmpty)
    }

    /// With no food open, a tag tap has nowhere to land and is ignored.
    func test_taggingIsIgnoredWhenNoFoodIsOpen() async {
        let store = TestStore(initialState: stateWithTwoFoods()) { CaptureFeature() }
        await store.send(.tagToggled("라멘"))
    }

    func test_pickingIsCaseInsensitive() async {
        let store = TestStore(
            initialState: stateWithTwoFoods(editing: ramenID, ramenTags: ["Ramen"])
        ) {
            CaptureFeature()
        }

        await store.send(.tagToggled("ramen")) { $0.candidates[0].tags = [] }
    }

    func test_newTagIsSavedToTheCatalogAndPickedStraightAway() async {
        let created = LockBox<[String]>([])
        let store = TestStore(initialState: stateWithTwoFoods(editing: ramenID)) {
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
            $0.candidates[0].tags = ["매운 라멘"]
        }
        await store.receive(\.tagCatalogLoaded) {
            $0.tagCatalog = ["매운 라멘"]
        }
        XCTAssertEqual(created.value, ["매운 라멘"])
    }

    func test_blankNewTagIsJustCleared() async {
        let store = TestStore(initialState: stateWithTwoFoods(editing: ramenID)) {
            CaptureFeature()
        }

        await store.send(.newTagTextChanged("   ")) { $0.newTagText = "   " }
        await store.send(.newTagSubmitted) { $0.newTagText = "" }
    }

    func test_ratingGoesOnlyToTheFoodBeingDescribed() async {
        let store = TestStore(initialState: stateWithTwoFoods(editing: gyozaID)) {
            CaptureFeature()
        }

        await store.send(.ratingChanged(4)) { $0.candidates[1].rating = 4 }
        XCTAssertNil(store.state.candidates[0].rating)
    }

    /// A rename has to reach every food already carrying the old name.
    func test_renamingATagRewritesItOnEveryFood() async {
        let renamed = LockBox<[String]>([])
        let store = TestStore(
            initialState: stateWithTwoFoods(
                editing: ramenID, ramenTags: ["라멘"], gyozaTags: ["라멘", "교자"]
            )
        ) {
            CaptureFeature()
        } withDependencies: {
            $0.persistence.renameTag = { from, to in renamed.append("\(from)->\(to)") }
            $0.persistence.allTags = { ["돈코츠", "교자"] }
        }

        await store.send(.renameTagRequested("라멘")) {
            $0.renamingTag = "라멘"
            $0.renameText = "라멘"
        }
        await store.send(.renameTextChanged("돈코츠")) { $0.renameText = "돈코츠" }
        await store.send(.renameConfirmed) {
            $0.renamingTag = nil
            $0.candidates[0].tags = ["돈코츠"]
            $0.candidates[1].tags = ["돈코츠", "교자"]
        }
        await store.receive(\.tagCatalogLoaded) {
            $0.tagCatalog = ["돈코츠", "교자"]
        }
        XCTAssertEqual(renamed.value, ["라멘->돈코츠"])
    }

    func test_renamingToTheSameNameDoesNothing() async {
        let store = TestStore(
            initialState: stateWithTwoFoods(editing: ramenID, ramenTags: ["라멘"])
        ) {
            CaptureFeature()
        }

        await store.send(.renameTagRequested("라멘")) {
            $0.renamingTag = "라멘"
            $0.renameText = "라멘"
        }
        await store.send(.renameConfirmed) { $0.renamingTag = nil }
    }

    func test_deletingATagDropsItFromEveryFood() async {
        let deleted = LockBox<[String]>([])
        let store = TestStore(
            initialState: stateWithTwoFoods(
                editing: ramenID, ramenTags: ["라멘", "우동"], gyozaTags: ["라멘"]
            )
        ) {
            CaptureFeature()
        } withDependencies: {
            $0.persistence.deleteTag = { deleted.append($0) }
            $0.persistence.allTags = { ["우동"] }
        }

        await store.send(.deleteTagRequested("라멘")) {
            $0.candidates[0].tags = ["우동"]
            $0.candidates[1].tags = []
        }
        await store.receive(\.tagCatalogLoaded) { $0.tagCatalog = ["우동"] }
        XCTAssertEqual(deleted.value, ["라멘"])
    }

    /// The catalog belongs to the user, not to one batch, so saving must not wipe it.
    func test_savingKeepsTheCatalogButClearsTheBatch() async {
        var state = stateWithTwoFoods(editing: ramenID, ramenTags: ["라멘"])
        state.tagCatalog = ["라멘", "우동"]
        let store = TestStore(initialState: state) { CaptureFeature() }
        let saved = [
            FoodEntrySnapshot(id: UUID(), fileName: "a.png", eatenAt: Date(), tags: ["라멘"])
        ]

        await store.send(.saved(saved)) {
            $0.candidates = []
            $0.editingCandidateID = nil
            $0.tagCatalog = ["라멘", "우동"]
            $0.savedEntries = saved
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
