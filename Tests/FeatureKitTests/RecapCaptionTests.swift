import XCTest
import ComposableArchitecture
import Models
@testable import FeatureKit

final class RecapCaptionTests: XCTestCase {
    @MainActor
    func test_onAppear_requestsCaptionInTheUILanguage() async {
        let meal = FoodEntrySnapshot(
            id: UUID(), fileName: "a.png",
            eatenAt: Date(timeIntervalSince1970: 1_000_000),
            place: PlaceInfo(id: "p1", name: "라멘집", address: "")
        )
        let requested = LockBox()
        let store = TestStore(initialState: RecapFeature.State()) {
            RecapFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_000_100))
            $0.locale = Locale(identifier: "ja_JP")
            $0.persistence.allEntries = { [meal] }
            $0.caption.weeklyCaption = { count, places, language in
                requested.set("\(count)|\(places.joined(separator: ","))|\(language)")
                return "おいしい一週間"
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.loaded)
        await store.receive(\.captionGenerated) { $0.caption = "おいしい一週間" }
        XCTAssertEqual(requested.value, "1|라멘집|ja")
    }

    @MainActor
    func test_captionStaysNilWhenAppleIntelligenceIsUnavailable() async {
        let meal = FoodEntrySnapshot(
            id: UUID(), fileName: "a.png",
            eatenAt: Date(timeIntervalSince1970: 1_000_000)
        )
        let store = TestStore(initialState: RecapFeature.State()) {
            RecapFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_000_100))
            $0.locale = Locale(identifier: "ko_KR")
            $0.persistence.allEntries = { [meal] }
            $0.caption.weeklyCaption = { _, _, _ in nil }   // model unavailable
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.loaded)
        await store.receive(\.captionGenerated) { $0.caption = nil }
    }

    @MainActor
    func test_userCanEditTheStoryCaption() async {
        let store = TestStore(initialState: RecapFeature.State()) {
            RecapFeature()
        }

        await store.send(.captionChanged("이번 주도 야무지게 먹었다")) {
            $0.caption = "이번 주도 야무지게 먹었다"
            $0.hasEditedCaption = true
        }
    }

    @MainActor
    func test_lateGeneratedCaptionDoesNotReplaceTheUsersLine() async {
        var state = RecapFeature.State()
        state.caption = "내가 쓴 한 줄"
        state.hasEditedCaption = true
        let store = TestStore(initialState: state) {
            RecapFeature()
        }

        await store.send(.captionGenerated("AI가 늦게 만든 문구"))
    }
}

/// Lock-backed box so the @Sendable dependency closure can record its input.
private final class LockBox: @unchecked Sendable {
    private var storage: String?
    private let lock = NSLock()
    func set(_ value: String) { lock.lock(); storage = value; lock.unlock() }
    var value: String? { lock.lock(); defer { lock.unlock() }; return storage }
}
