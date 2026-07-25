import XCTest
import MapKit
import Models
@testable import ClientKit

final class PlaceSearchClientTests: XCTestCase {
    func test_placeInfo_fromMapItem_mapsCoreFields() {
        let coord = CLLocationCoordinate2D(latitude: 33.59, longitude: 130.40)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        item.name = "라멘집"
        let place = PlaceInfo(mapItem: item)
        XCTAssertEqual(place?.name, "라멘집")
        XCTAssertEqual(place?.coordinate?.latitude ?? 0, 33.59, accuracy: 0.001)
        XCTAssertEqual(place?.coordinate?.longitude ?? 0, 130.40, accuracy: 0.001)
    }

    func test_liveValue_returnsFoodPlaces_orSkipsOffline() async throws {
        let client = PlaceSearchClient.liveValue
        let places: [PlaceInfo]
        do {
            places = try await client.nearby(Coordinate(latitude: 35.6595, longitude: 139.7005))
        } catch {
            throw XCTSkip("MapKit search unavailable: \(error.localizedDescription)")
        }
        if places.isEmpty { throw XCTSkip("MapKit returned no results (offline/CI)") }
        XCTAssertTrue(places.allSatisfy { !$0.name.isEmpty })
    }
}
