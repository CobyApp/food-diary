import Foundation
import CoreLocation
import MapKit
import Dependencies
import DependenciesMacros
import Models

@DependencyClient
public struct PlaceSearchClient: Sendable {
    public var nearby: @Sendable (_ coordinate: Coordinate) async throws -> [PlaceInfo]
}

extension PlaceInfo {
    init?(mapItem: MKMapItem) {
        guard let name = mapItem.name else { return nil }
        let c = mapItem.placemark.coordinate
        self.init(
            id: mapItem.identifier?.rawValue ?? "\(name)_\(c.latitude)_\(c.longitude)",
            name: name,
            address: mapItem.placemark.title ?? "",
            coordinate: Coordinate(latitude: c.latitude, longitude: c.longitude),
            googlePlaceId: nil
        )
    }
}

extension PlaceSearchClient: DependencyKey {
    // Apple MapKit points-of-interest search (free, no API key). Searches food
    // POIs within ~500m of the photo's coordinate.
    public static let liveValue = PlaceSearchClient(
        nearby: { coordinate in
            let request = MKLocalPointsOfInterestRequest(
                center: CLLocationCoordinate2D(latitude: coordinate.latitude,
                                               longitude: coordinate.longitude),
                radius: 500
            )
            request.pointOfInterestFilter = MKPointOfInterestFilter(
                including: [.restaurant, .cafe, .bakery, .foodMarket]
            )
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.compactMap(PlaceInfo.init(mapItem:))
        }
    )
}

extension PlaceSearchClient: TestDependencyKey {
    public static let testValue = PlaceSearchClient()
    public static let previewValue = PlaceSearchClient(
        nearby: { _ in
            [PlaceInfo(id: "preview", name: "미리보기 식당", address: "미리보기 주소")]
        }
    )
}

public extension DependencyValues {
    var placeSearch: PlaceSearchClient {
        get { self[PlaceSearchClient.self] }
        set { self[PlaceSearchClient.self] = newValue }
    }
}
