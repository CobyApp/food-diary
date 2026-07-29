import ComposableArchitecture
import Models
import XCTest
@testable import FeatureKit

final class RecapFeatureTests: XCTestCase {
    @MainActor
    func test_onAppear_defaultsToTodayAndRangeCanBeChanged() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let todayCutout = CutoutSnapshot(
            id: UUID(), fileName: "today.png", createdAt: now, label: nil
        )
        let yesterdayCutout = CutoutSnapshot(
            id: UUID(), fileName: "yesterday.png", createdAt: now, label: nil
        )
        let meals = [
            MealSnapshot(
                id: UUID(), eatenAt: now.addingTimeInterval(-60),
                place: nil, tags: [], rating: nil, cutouts: [todayCutout]
            ),
            MealSnapshot(
                id: UUID(), eatenAt: now.addingTimeInterval(-86_400),
                place: nil, tags: [], rating: nil, cutouts: [yesterdayCutout]
            ),
        ]
        let store = TestStore(initialState: RecapFeature.State()) {
            RecapFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.locale = Locale(identifier: "ko_KR")
            $0.persistence.allMeals = { meals }
            $0.caption.weeklyCaption = { _, _, _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.loaded) {
            $0.isLoading = false
            $0.weekCutouts = [todayCutout]
            $0.mealCount = 1
        }
        await store.receive(\.captionGenerated) { $0.caption = nil }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        await store.send(.dateRangeChanged(start: yesterday, end: now)) {
            $0.startDate = Calendar.current.startOfDay(for: yesterday)
            $0.endDate = Calendar.current.startOfDay(for: now)
            $0.isLoading = true
            $0.caption = nil
            $0.hasEditedCaption = false
        }
        await store.receive(\.loaded) {
            $0.isLoading = false
            $0.weekCutouts = [todayCutout, yesterdayCutout]
            $0.mealCount = 2
        }
        await store.receive(\.captionGenerated) { $0.caption = nil }
    }
}
