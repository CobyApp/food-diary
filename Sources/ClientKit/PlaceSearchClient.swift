import Foundation
import Dependencies
import DependenciesMacros
import Models

@DependencyClient
public struct PlaceSearchClient: Sendable {
    public var nearby: @Sendable (_ coordinate: Coordinate) async throws -> [PlaceInfo]
}

extension PlaceSearchClient: DependencyKey {
    // v1: Google Places is not wired yet. Return deterministic mock data near
    // the requested coordinate so the flow is fully exercisable offline.
    public static let liveValue = PlaceSearchClient(
        nearby: { coordinate in
            let names = ["라멘 이치란", "스시로", "규카츠 모토무라", "이키나리 스테이크", "코메다 커피"]
            return names.enumerated().map { index, name in
                PlaceInfo(
                    id: "mock_\(index)",
                    name: name,
                    address: "후쿠오카시 근처 \(index + 1)번지",
                    coordinate: Coordinate(
                        latitude: coordinate.latitude + Double(index) * 0.0003,
                        longitude: coordinate.longitude + Double(index) * 0.0003
                    ),
                    googlePlaceId: nil
                )
            }
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
