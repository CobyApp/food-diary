import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import XCTest
@testable import FeatureKit
@testable import Models

/// Writes the App Store screenshots, one set per language.
///
/// Not part of the normal suite — it writes files and takes seconds, so it only
/// runs when asked:
///
///     GENERATE_STORE_SCREENSHOTS=1 xcodebuild test … -only-testing:FeatureKitTests/StoreScreenshotGenerator
///
/// or just `Scripts/screenshots.sh`.
///
/// Rendered with `ImageRenderer` rather than captured from a simulator on
/// purpose: cutouts come from Vision, which does not run in the simulator, so a
/// captured screen would be an empty board. Rendering also fixes the pixel size
/// exactly, which the store requires.
@MainActor
final class StoreScreenshotGenerator: XCTestCase {

    /// iPhone 6.9" — the only iPhone size the store now asks for. It scales this
    /// down for every smaller device itself.
    private static let pointSize = CGSize(width: 440, height: 956)
    private static let scale: CGFloat = 3   // 1320 × 2868

    private static let languages = ["ko", "en", "ja", "zh-Hans"]

    func test_generateStoreScreenshots() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GENERATE_STORE_SCREENSHOTS"] == "1",
            "Set GENERATE_STORE_SCREENSHOTS=1 to write store screenshots."
        )

        let root = try outputRoot()
        var written: [String] = []

        for language in Self.languages {
            let bundle = try localizedBundle(for: language)
            L10n.overrideBundle = bundle
            L10n.overrideLocale = Locale(identifier: language)
            defer {
                L10n.overrideBundle = nil
                L10n.overrideLocale = nil
            }

            let folder = root.appendingPathComponent(language, isDirectory: true)
            try FileManager.default.createDirectory(
                at: folder, withIntermediateDirectories: true
            )

            for (index, poster) in posters(language: language).enumerated() {
                let url = folder.appendingPathComponent(
                    String(format: "%02d_%@.png", index + 1, poster.slug)
                )
                let data = try render(poster.view)
                try data.write(to: url)
                written.append("\(language)/\(url.lastPathComponent)")
            }
        }

        XCTAssertEqual(written.count, Self.languages.count * 5)
        print("Store screenshots written to \(root.path):")
        written.forEach { print("  \($0)") }
    }

    // MARK: - Rendering

    /// PNG at exactly 1320 × 2868, RGB, no alpha channel — the store rejects
    /// anything else, including an off-by-one size or a stray alpha channel.
    private func render<V: View>(_ view: V) throws -> Data {
        let renderer = ImageRenderer(
            content: view
                .frame(width: Self.pointSize.width, height: Self.pointSize.height)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = Self.scale
        renderer.isOpaque = true

        let image = try XCTUnwrap(renderer.uiImage, "ImageRenderer produced nothing")
        let pixels = CGSize(
            width: Self.pointSize.width * Self.scale,
            height: Self.pointSize.height * Self.scale
        )
        XCTAssertEqual(image.size.width * image.scale, pixels.width, accuracy: 0.5)
        XCTAssertEqual(image.size.height * image.scale, pixels.height, accuracy: 0.5)

        return try XCTUnwrap(Self.opaquePNG(from: image, pixels: pixels))
    }

    /// Redrawn into a bitmap with no alpha channel at all, then encoded by
    /// ImageIO.
    ///
    /// `UIImage.pngData()` writes an alpha channel even for a fully opaque image,
    /// and `UIGraphicsImageRendererFormat.opaque` does not change that — the store
    /// rejects the result. Only a context created with `noneSkipLast` produces a
    /// three-channel PNG.
    private static func opaquePNG(from image: UIImage, pixels: CGSize) -> Data? {
        guard let source = image.cgImage else { return nil }
        let width = Int(pixels.width.rounded())
        let height = Int(pixels.height.rounded())
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let flattened = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, "public.png" as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, flattened, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    // MARK: - Output location

    /// `fastlane/screenshots/<language>/`, where fastlane's deliver looks.
    private func outputRoot() throws -> URL {
        let root = Self.repositoryRoot
            .appendingPathComponent("fastlane", isDirectory: true)
            .appendingPathComponent("screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// Read straight from the source tree.
    ///
    /// The strings belong to the app target, and these tests are not hosted by the
    /// app, so no loaded bundle contains them. The repository does.
    private func localizedBundle(for language: String) throws -> Bundle {
        let path = Self.repositoryRoot
            .appendingPathComponent("Sources/FoodDiary/Resources")
            .appendingPathComponent("\(language).lproj")
        let bundle = try XCTUnwrap(
            Bundle(path: path.path),
            "No \(language).lproj at \(path.path)"
        )
        return bundle
    }

    /// The checked-out repository, derived from this file's own path.
    static let repositoryRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)   // …/Tests/FeatureKitTests/this.swift
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        return url
    }()

    // MARK: - The posters

    private struct Poster {
        let slug: String
        let view: AnyView
    }

    private func posters(language: String) -> [Poster] {
        let copy = StoreCopy.forLanguage(language)
        let foods = StoreSampleFood.all
        return [
            Poster(
                slug: "board",
                view: AnyView(
                    StorePoster(headline: copy.board, theme: .strawberryCheck) {
                        StoreBoardScene(foods: foods)
                    }
                )
            ),
            Poster(
                slug: "cutout",
                view: AnyView(
                    StorePoster(headline: copy.cutout, theme: .creamDiary) {
                        StoreCutoutScene(foods: foods)
                    }
                )
            ),
            Poster(
                slug: "tags",
                view: AnyView(
                    StorePoster(headline: copy.tags, theme: .lavenderPop) {
                        StoreTagScene(food: foods[0], tags: copy.sampleTags)
                    }
                )
            ),
            Poster(
                slug: "drawer",
                view: AnyView(
                    StorePoster(headline: copy.drawer, theme: .sodaBlue) {
                        StoreDrawerScene(foods: foods, tags: copy.sampleTags)
                    }
                )
            ),
            Poster(
                slug: "recap",
                view: AnyView(
                    StorePoster(
                        headline: copy.recap,
                        theme: .strawberryCheck,
                        plated: false
                    ) {
                        RecapStoryCard(
                            images: foods.map(\.image),
                            mealCount: foods.count,
                            caption: copy.recapCaption,
                            theme: .creamDiary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.appCard, lineWidth: 4)
                        }
                        .scaleEffect(0.95)
                    }
                )
            ),
        ]
    }
}
