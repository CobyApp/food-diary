import ClientKit
import CoreImage
import ImageIO
import SwiftUI
import UIKit

public actor CutoutImageLoader {
    public static let shared = CutoutImageLoader()

    private let cache: NSCache<NSString, UIImage>
    private let renderContext: CIContext

    public init() {
        cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 48 * 1_024 * 1_024
        renderContext = CIContext(options: [.cacheIntermediates: false])
    }

    public func image(
        fileName: String? = nil,
        data immediateData: Data? = nil,
        cacheKey: String,
        maxPixelDimension: Int = 720
    ) -> UIImage? {
        let key = "bold-outline-v3-\(cacheKey)-\(maxPixelDimension)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let data: Data?
        if let immediateData {
            data = immediateData
        } else if let fileName {
            data = ImageStore.disk(directory: ImageStore.cutoutsDirectory).load(fileName)
        } else {
            data = nil
        }

        guard
            let data,
            let image = Self.stickerImage(
                data,
                maxPixelDimension: maxPixelDimension,
                context: renderContext
            )
        else {
            return nil
        }
        cache.setObject(image, forKey: key, cost: Self.estimatedCost(of: image))
        return image
    }

    public func images(
        fileNames: [String],
        maxPixelDimension: Int = 720
    ) -> [UIImage] {
        fileNames.compactMap {
            image(
                fileName: $0,
                cacheKey: $0,
                maxPixelDimension: maxPixelDimension
            )
        }
    }

    private static func stickerImage(
        _ data: Data,
        maxPixelDimension: Int,
        context: CIContext
    ) -> UIImage? {
        autoreleasepool {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                return UIImage(data: data)
            }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let sourceImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                options as CFDictionary
            ) else {
                return UIImage(data: data)
            }

            let longestSide = CGFloat(max(sourceImage.width, sourceImage.height))
            let outlineWidth = min(24, max(10, longestSide * 0.032))
            let padding = ceil(outlineWidth + 5)
            let canvas = CGRect(
                x: 0,
                y: 0,
                width: CGFloat(sourceImage.width) + padding * 2,
                height: CGFloat(sourceImage.height) + padding * 2
            )
            let transparentCanvas = CIImage(
                color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)
            )
            .cropped(to: canvas)
            let cutout = CIImage(cgImage: sourceImage)
                .transformed(by: CGAffineTransform(translationX: padding, y: padding))
                .composited(over: transparentCanvas)

            let whiteSilhouette = cutout.applyingFilter(
                "CIColorMatrix",
                parameters: [
                    "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                    "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0),
                ]
            )
            let outline = whiteSilhouette
                .applyingFilter(
                    "CIMorphologyMaximum",
                    parameters: ["inputRadius": outlineWidth]
                )
                .cropped(to: canvas)
            let sticker = cutout
                .composited(over: outline)
                .cropped(to: canvas)

            guard let rendered = context.createCGImage(sticker, from: canvas) else {
                return UIImage(cgImage: sourceImage)
            }
            return UIImage(cgImage: rendered)
        }
    }

    private static func estimatedCost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

public struct CutoutImage: View {
    private let fileName: String?
    private let immediateData: Data?
    private let immediateImage: UIImage?
    private let cacheKey: String
    private let maxPixelDimension: Int

    @State private var loadedImage: UIImage?

    public init(fileName: String, maxPixelDimension: Int = 720) {
        self.fileName = fileName
        immediateData = nil
        immediateImage = nil
        cacheKey = fileName
        self.maxPixelDimension = maxPixelDimension
    }

    public init(data: Data, cacheKey: String? = nil, maxPixelDimension: Int = 720) {
        fileName = nil
        immediateData = data
        immediateImage = nil
        let dataKey = Self.inlineKey(for: data)
        self.cacheKey = cacheKey.map { "\($0)-\(dataKey)" } ?? dataKey
        self.maxPixelDimension = maxPixelDimension
    }

    public init(image: UIImage) {
        fileName = nil
        immediateData = nil
        immediateImage = image
        cacheKey = "image-\(ObjectIdentifier(image).hashValue)"
        maxPixelDimension = 0
    }

    public var body: some View {
        Group {
            if let image = immediateImage ?? loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "fork.knife")
                            .font(.caption.bold())
                            .foregroundStyle(.appMuted.opacity(0.55))
                            .symbolEffect(.pulse)
                    }
            }
        }
        .task(id: cacheKey) {
            guard immediateImage == nil else { return }
            loadedImage = nil
            loadedImage = await CutoutImageLoader.shared.image(
                fileName: fileName,
                data: immediateData,
                cacheKey: cacheKey,
                maxPixelDimension: maxPixelDimension
            )
        }
    }

    private static func inlineKey(for data: Data) -> String {
        let prefix = data.prefix(12).map { String(format: "%02x", $0) }.joined()
        return "inline-\(data.count)-\(prefix)"
    }
}
