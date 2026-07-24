import Foundation
import ImageIO
import Dependencies
import DependenciesMacros
import Models

@DependencyClient
public struct PhotoLocationClient: Sendable {
    public var coordinate: @Sendable (_ imageData: Data) -> Coordinate?
}

extension PhotoLocationClient: DependencyKey {
    public static let liveValue = PhotoLocationClient(
        coordinate: { data in
            guard
                let src = CGImageSourceCreateWithData(data as CFData, nil),
                let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
                let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
                let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
                let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
                let lon = gps[kCGImagePropertyGPSLongitude] as? Double,
                let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String
            else { return nil }
            let latitude = latRef.uppercased() == "S" ? -lat : lat
            let longitude = lonRef.uppercased() == "W" ? -lon : lon
            return Coordinate(latitude: latitude, longitude: longitude)
        }
    )
}

extension PhotoLocationClient: TestDependencyKey {
    public static let testValue = PhotoLocationClient()
    public static let previewValue = PhotoLocationClient(
        coordinate: { _ in Coordinate(latitude: 33.5902, longitude: 130.4017) }
    )
}

public extension DependencyValues {
    var photoLocation: PhotoLocationClient {
        get { self[PhotoLocationClient.self] }
        set { self[PhotoLocationClient.self] = newValue }
    }
}
