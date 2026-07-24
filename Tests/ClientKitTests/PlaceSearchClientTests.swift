import XCTest
import Models
@testable import ClientKit

final class PlaceSearchClientTests: XCTestCase {
    func test_liveValue_returnsNonEmptyMockNearbyPlaces() async throws {
        let client = PlaceSearchClient.liveValue
        let places = try await client.nearby(Coordinate(latitude: 33.59, longitude: 130.40))
        XCTAssertFalse(places.isEmpty)
        XCTAssertTrue(places.allSatisfy { !$0.name.isEmpty })
    }
}
