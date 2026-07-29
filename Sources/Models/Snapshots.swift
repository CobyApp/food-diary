import Foundation

/// A `Sendable` copy of one food's record, safe to hand across actor boundaries.
/// `@Model` objects never leave the persistence actor.
public struct FoodEntrySnapshot: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let fileName: String
    public let eatenAt: Date
    public let label: String?
    public let place: PlaceInfo?
    public let tags: [String]
    public let rating: Int?

    public init(
        id: UUID,
        fileName: String,
        eatenAt: Date,
        label: String? = nil,
        place: PlaceInfo? = nil,
        tags: [String] = [],
        rating: Int? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.eatenAt = eatenAt
        self.label = label
        self.place = place
        self.tags = tags
        self.rating = rating
    }
}
