import Foundation
import Models

public struct MealStreak: Equatable, Sendable {
    public var current: Int
    public var best: Int

    public init(current: Int = 0, best: Int = 0) {
        self.current = current
        self.best = best
    }

    public static func calculate(
        entries: [FoodEntrySnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> MealStreak {
        let days = Set(entries.map { calendar.startOfDay(for: $0.eatenAt) })
        guard !days.isEmpty else { return MealStreak() }

        let ordered = days.sorted()
        var best = 1
        var run = 1
        for index in ordered.indices.dropFirst() {
            let previous = ordered[ordered.index(before: index)]
            if calendar.dateComponents([.day], from: previous, to: ordered[index]).day == 1 {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }

        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let latest = ordered.last!
        guard latest == today || latest == yesterday else {
            return MealStreak(current: 0, best: best)
        }

        var current = 0
        var cursor = latest
        while days.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return MealStreak(current: current, best: max(best, current))
    }
}
