import Foundation
import SwiftData

/// One food, one record.
///
/// There used to be a `Meal` holding several cutouts, which meant a handful of
/// dishes photographed together shared a single set of tags, rating and place.
/// Each food now carries its own, so a plate of ramen and the gyoza next to it
/// are described separately.
@Model
public final class FoodEntry {
    public var id: UUID
    /// Name of the cutout PNG in the image store.
    public var fileName: String
    public var eatenAt: Date
    public var label: String?
    public var placeData: Data?
    public var tags: [String]
    public var rating: Int?

    public init(
        id: UUID = UUID(),
        fileName: String,
        eatenAt: Date = Date(),
        label: String? = nil,
        tags: [String] = [],
        rating: Int? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.eatenAt = eatenAt
        self.label = label
        self.tags = tags
        self.rating = rating
    }

    // PlaceInfo is stored as encoded JSON so it stays a plain value type.
    public var place: PlaceInfo? {
        get { placeData.flatMap { try? JSONDecoder().decode(PlaceInfo.self, from: $0) } }
        set { placeData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    public func snapshot() -> FoodEntrySnapshot {
        FoodEntrySnapshot(
            id: id,
            fileName: fileName,
            eatenAt: eatenAt,
            label: label,
            place: place,
            tags: tags,
            rating: rating
        )
    }
}
