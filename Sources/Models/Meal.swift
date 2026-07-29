import Foundation
import SwiftData

@Model
public final class Meal {
    public var id: UUID
    public var eatenAt: Date
    public var placeData: Data?
    public var tags: [String]
    public var rating: Int?
    @Relationship(deleteRule: .cascade, inverse: \FoodCutout.meal)
    public var cutouts: [FoodCutout]

    public init(
        id: UUID = UUID(),
        eatenAt: Date = Date(),
        tags: [String] = [],
        rating: Int? = nil
    ) {
        self.id = id
        self.eatenAt = eatenAt
        self.tags = tags
        self.rating = rating
        self.cutouts = []
    }

    // PlaceInfo is stored as encoded JSON so it stays a plain value type.
    public var place: PlaceInfo? {
        get { placeData.flatMap { try? JSONDecoder().decode(PlaceInfo.self, from: $0) } }
        set { placeData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    public func snapshot() -> MealSnapshot {
        MealSnapshot(
            id: id,
            eatenAt: eatenAt,
            place: place,
            tags: tags,
            rating: rating,
            cutouts: cutouts
                .sorted { $0.createdAt < $1.createdAt }
                .map { $0.snapshot() }
        )
    }
}
