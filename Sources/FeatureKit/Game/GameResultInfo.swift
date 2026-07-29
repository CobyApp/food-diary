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

    /// Builds the richer result payload from a food's record (nil when unknown).
    public static func from(_ entry: FoodEntrySnapshot?) -> GameResultInfo? {
        guard let entry else { return nil }
        return GameResultInfo(
            placeName: entry.place?.name ?? "",
            dateText: entry.eatenAt.formatted(.dateTime.month().day().weekday()),
            tags: entry.tags,
            rating: entry.rating
        )
    }
}
