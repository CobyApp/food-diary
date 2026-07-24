public struct PlaceInfo: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var address: String
    public var coordinate: Coordinate?
    public var googlePlaceId: String?

    public init(
        id: String,
        name: String,
        address: String,
        coordinate: Coordinate? = nil,
        googlePlaceId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.googlePlaceId = googlePlaceId
    }
}
