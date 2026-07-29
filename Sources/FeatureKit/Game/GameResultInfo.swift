import Foundation
import Models

public struct GameResultInfo: Equatable, Sendable {
    public let placeName: String
    public let dateText: String
    public let tags: [String]
    public let rating: Int?

    public init(placeName: String, dateText: String, tags: [String], rating: Int?) {
        self.placeName = placeName
        self.dateText = dateText
        self.tags = tags
        self.rating = rating
    }

    /// Builds the richer result payload from a meal snapshot (nil when unknown).
    public static func from(_ meal: MealSnapshot?) -> GameResultInfo? {
        guard let meal else { return nil }
        return GameResultInfo(
            placeName: meal.place?.name ?? "",
            dateText: meal.eatenAt.formatted(.dateTime.month().day().weekday()),
            tags: meal.tags,
            rating: meal.rating
        )
    }
}
