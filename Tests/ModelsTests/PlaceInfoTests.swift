import XCTest
@testable import Models

final class PlaceInfoTests: XCTestCase {
    func test_placeInfo_roundTripsThroughJSON() throws {
        let place = PlaceInfo(
            id: "abc",
            name: "라멘집",
            address: "후쿠오카 1-2-3",
            coordinate: Coordinate(latitude: 33.59, longitude: 130.40),
            googlePlaceId: "gp_1"
        )
        let data = try JSONEncoder().encode(place)
        let decoded = try JSONDecoder().decode(PlaceInfo.self, from: data)
        XCTAssertEqual(decoded, place)
    }
}
