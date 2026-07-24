import XCTest
import Models
@testable import ClientKit

final class PhotoLocationClientTests: XCTestCase {
    func test_coordinate_readsGPSFromExif() throws {
        let url = Bundle.module.url(forResource: "gps-tagged", withExtension: "jpg")
        let data = try Data(contentsOf: XCTUnwrap(url))

        let client = PhotoLocationClient.liveValue
        let coord = try XCTUnwrap(client.coordinate(data))

        // gps-tagged.jpg is tagged at approx (37.7749, -122.4194).
        XCTAssertEqual(coord.latitude, 37.7749, accuracy: 0.01)
        XCTAssertEqual(coord.longitude, -122.4194, accuracy: 0.01)
    }

    func test_coordinate_returnsNil_whenNoGPS() {
        let client = PhotoLocationClient.liveValue
        XCTAssertNil(client.coordinate(Data([0xFF, 0xD8, 0xFF])))
    }
}
