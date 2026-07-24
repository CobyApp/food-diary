import Foundation
import Vision
import CoreImage
import Dependencies
import DependenciesMacros

public struct Cutout: Equatable, Sendable {
    public var pngData: Data
    public init(pngData: Data) { self.pngData = pngData }
}

@DependencyClient
public struct FoodCutoutClient: Sendable {
    public var extract: @Sendable (_ imageData: Data) async throws -> [Cutout]
}

extension FoodCutoutClient: DependencyKey {
    public static let liveValue = FoodCutoutClient(
        extract: { imageData in
            guard let ciImage = CIImage(data: imageData) else { return [] }
            let handler = VNImageRequestHandler(ciImage: ciImage)
            let request = VNGenerateForegroundInstanceMaskRequest()
            try handler.perform([request])
            guard let result = request.results?.first else { return [] }

            let context = CIContext()
            var cutouts: [Cutout] = []
            for instance in result.allInstances {
                let buffer = try result.generateMaskedImage(
                    ofInstances: [instance],
                    from: handler,
                    croppedToInstancesExtent: true
                )
                let masked = CIImage(cvPixelBuffer: buffer)
                guard let cg = context.createCGImage(masked, from: masked.extent) else { continue }
                if let png = Self.pngData(from: cg) {
                    cutouts.append(Cutout(pngData: png))
                }
            }
            return cutouts
        }
    )

    // Encode a CGImage (with alpha) to PNG data without UIKit.
    private static func pngData(from cgImage: CGImage) -> Data? {
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        return context.pngRepresentation(
            of: ciImage,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
    }
}

extension FoodCutoutClient: TestDependencyKey {
    public static let testValue = FoodCutoutClient()
    public static let previewValue = FoodCutoutClient(
        extract: { _ in [Cutout(pngData: Data([0x89, 0x50, 0x4E, 0x47]))] }
    )
}

public extension DependencyValues {
    var foodCutout: FoodCutoutClient {
        get { self[FoodCutoutClient.self] }
        set { self[FoodCutoutClient.self] = newValue }
    }
}
