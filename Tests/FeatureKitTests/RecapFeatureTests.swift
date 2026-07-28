import ComposableArchitecture
import Models
import XCTest
@testable import FeatureKit

final class RecapFeatureTests: XCTestCase {
    @MainActor
    func test_onAppear_filtersToRecentMeals() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recentCutout = CutoutSnapshot(
            id: UUID(), fileName: "recent.png", createdAt: now, label: nil
        )
        let meals = [
            MealSnapshot(
                id: UUID(), eatenAt: now.addingTimeInterval(-86_400),
                place: nil, memo: "", rating: nil, cutouts: [recentCutout]
            ),
            MealSnapshot(
                id: UUID(), eatenAt: now.addingTimeInterval(-30 * 86_400),
                place: nil, memo: "", rating: nil,
                cutouts: [.init(id: UUID(), fileName: "old.png", createdAt: now, label: nil)]
            ),
        ]
        let store = TestStore(initialState: RecapFeature.State()) {
            RecapFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.locale = Locale(identifier: "ko_KR")
            $0.persistence.allMeals = { meals }
            // This test is about week filtering; the caption is covered separately.
            $0.caption.weeklyCaption = { _, _, _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.loaded) {
            $0.isLoading = false
            $0.weekCutouts = [recentCutout]
            $0.mealCount = 1
        }
        // The same effect then asks for a caption; the stub declines it.
        await store.receive(\.captionGenerated) { $0.caption = nil }
    }
}
