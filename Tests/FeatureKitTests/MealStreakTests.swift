import Models
import XCTest
@testable import FeatureKit

final class MealStreakTests: XCTestCase {
    func test_calculatesCurrentAndBestRuns() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let today = calendar.startOfDay(for: now)
        let offsets = [0, -1, -2, -6, -7]
        let meals = offsets.map { offset in
            FoodEntrySnapshot(
                id: UUID(),
                fileName: "\(offset).png",
                eatenAt: calendar.date(byAdding: .day, value: offset, to: today)!
            )
        }

        XCTAssertEqual(
            MealStreak.calculate(entries: meals, now: now, calendar: calendar),
            MealStreak(current: 3, best: 3)
        )
    }
}
