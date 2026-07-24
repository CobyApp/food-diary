import Foundation

public struct CutoutSnapshot: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let fileName: String
    public let createdAt: Date
    public let label: String?

    public init(id: UUID, fileName: String, createdAt: Date, label: String?) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.label = label
    }
}

public struct MealSnapshot: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let eatenAt: Date
    public let place: PlaceInfo?
    public let memo: String
    public let rating: Int?
    public let cutouts: [CutoutSnapshot]

    public init(
        id: UUID,
        eatenAt: Date,
        place: PlaceInfo?,
        memo: String,
        rating: Int?,
        cutouts: [CutoutSnapshot]
    ) {
        self.id = id
        self.eatenAt = eatenAt
        self.place = place
        self.memo = memo
        self.rating = rating
        self.cutouts = cutouts
    }
}
