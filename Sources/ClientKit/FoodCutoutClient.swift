import Foundation
import Vision
import CoreImage
import ImageIO
import Dependencies
import DependenciesMacros

public struct Cutout: Equatable, Sendable {
    public var pngData: Data
    public init(pngData: Data) { self.pngData = pngData }
}

@DependencyClient
public struct FoodCutoutClient: Sendable {
    public var extract: @Sendable (_ imageData: Data) async throws -> [Cutout]
    public var rotateClockwise: @Sendable (_ pngData: Data) async -> Data?
}

extension FoodCutoutClient: DependencyKey {
    public static let liveValue = FoodCutoutClient(
        extract: { imageData in
            guard let ciImage = Self.downsampledImage(from: imageData, maxPixelDimension: 2_560) else {
                return []
            }
            let handler = VNImageRequestHandler(ciImage: ciImage)
            let request = VNGenerateForegroundInstanceMaskRequest()
            try handler.perform([request])
            guard let result = request.results?.first else { return [] }

            let context = CIContext(options: [.cacheIntermediates: false])
            var cutouts: [Cutout] = []
            for instance in result.allInstances {
                if let cutout = try autoreleasepool(invoking: {
                    let buffer = try result.generateMaskedImage(
                        ofInstances: [instance],
                        from: handler,
                        croppedToInstancesExtent: true
                    )
                    let masked = CIImage(cvPixelBuffer: buffer)
                    return Self.pngData(
                        from: masked,
                        context: context,
                        maxPixelDimension: 1_600
                    ).map(Cutout.init(pngData:))
                }) {
                    cutouts.append(cutout)
                }
            }
            return cutouts
        },
        rotateClockwise: { pngData in
            autoreleasepool {
                guard let image = CIImage(data: pngData) else { return nil }
                let rotated = image.oriented(.right)
                let normalized = rotated.transformed(
                    by: CGAffineTransform(
                        translationX: -rotated.extent.minX,
                        y: -rotated.extent.minY
                    )
                )
                let context = CIContext(options: [.cacheIntermediates: false])
                return context.pngRepresentation(
                    of: normalized,
                    format: .RGBA8,
                    colorSpace: CGColorSpaceCreateDeviceRGB()
                )
            }
        }
    )

    private static func downsampledImage(from data: Data, maxPixelDimension: Int) -> CIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return CIImage(cgImage: image)
    }

    private static func pngData(
        from image: CIImage,
        context: CIContext,
        maxPixelDimension: CGFloat
    ) -> Data? {
        let longestSide = max(image.extent.width, image.extent.height)
        let scale = longestSide > maxPixelDimension ? maxPixelDimension / longestSide : 1
        let output = scale < 1
            ? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            : image
        return context.pngRepresentation(
            of: output,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
    }
}

extension FoodCutoutClient: TestDependencyKey {
    public static let testValue = FoodCutoutClient()
    public static let previewValue = FoodCutoutClient(
        extract: { _ in [Cutout(pngData: Data([0x89, 0x50, 0x4E, 0x47]))] },
        rotateClockwise: { $0 }
    )
}

public extension DependencyValues {
    var foodCutout: FoodCutoutClient {
        get { self[FoodCutoutClient.self] }
        set { self[FoodCutoutClient.self] = newValue }
    }
}
