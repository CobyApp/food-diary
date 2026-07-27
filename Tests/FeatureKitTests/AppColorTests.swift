import XCTest
import SwiftUI
@testable import FeatureKit

final class AppColorTests: XCTestCase {
    func test_colorHex_parsesRGBChannels() throws {
        let ui = UIColor(Color(hex: 0x8FBEEA))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Double(r), Double(0x8F) / 255, accuracy: 0.01)
        XCTAssertEqual(Double(g), Double(0xBE) / 255, accuracy: 0.01)
        XCTAssertEqual(Double(b), Double(0xEA) / 255, accuracy: 0.01)
        XCTAssertEqual(Double(a), 1.0, accuracy: 0.01)
    }

    func test_stickerTint_rotatesThroughAllCases() {
        XCTAssertEqual(StickerTint.rotating(0), StickerTint.allCases[0])
        XCTAssertEqual(StickerTint.rotating(StickerTint.allCases.count),
                       StickerTint.allCases[0])
    }

    func test_cutoutLoader_buildsTransparentShapeFollowingSticker() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let data = UIGraphicsImageRenderer(
            size: CGSize(width: 40, height: 40),
            format: format
        ).pngData { context in
            UIColor.systemPink.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 8, y: 8, width: 24, height: 24))
        }

        let loaded = await CutoutImageLoader.shared.image(
            data: data,
            cacheKey: "shape-test",
            maxPixelDimension: 80
        )
        let sticker = try XCTUnwrap(loaded)
        let image = try XCTUnwrap(sticker.cgImage)

        XCTAssertGreaterThanOrEqual(image.width, 60, "sticker needs a bold padded outline")
        XCTAssertGreaterThan(alpha(of: image, x: image.width / 2, y: image.height / 2), 200)
        XCTAssertEqual(alpha(of: image, x: 0, y: 0), 0, "sticker corners must stay transparent")
    }

    private func alpha(of image: CGImage, x: Int, y: Int) -> UInt8 {
        guard let pixel = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else {
            return 0
        }
        var rgba = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &rgba,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return rgba[3]
    }
}
