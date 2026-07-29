import XCTest
import SwiftUI
@testable import FeatureKit

final class RecapStoryCardTests: XCTestCase {
    /// The share image must be exactly 1080x1920 px so it fills an Instagram
    /// Story with no letterboxing.
    @MainActor
    func test_storyCardExportsAtInstagramStorySize() throws {
        let swatch = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }

        let renderer = ImageRenderer(
            content: RecapStoryCard(
                images: [swatch, swatch, swatch],
                mealCount: 3
            )
            .frame(width: RecapStoryCard.size.width, height: RecapStoryCard.size.height)
        )
        renderer.scale = 3

        let image = try XCTUnwrap(renderer.uiImage)
        XCTAssertEqual(image.size.width * image.scale, 1080, accuracy: 2)
        XCTAssertEqual(image.size.height * image.scale, 1920, accuracy: 2)
    }

    /// 9:16 keeps the card Story-shaped regardless of the pixel scale used.
    func test_storySizeIsNineBySixteen() {
        let ratio = RecapStoryCard.size.width / RecapStoryCard.size.height
        XCTAssertEqual(ratio, 9.0 / 16.0, accuracy: 0.001)
    }

    @MainActor
    func test_everyBoardThemeRendersWithSavedStickerPositions() {
        let swatch = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image {
            UIColor.systemPink.setFill()
            $0.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        let positions = [
            StickerBoardPlacement(xFraction: 0.22, y: 90),
            StickerBoardPlacement(xFraction: 0.76, y: 230),
        ]

        for theme in StickerBoardTheme.allCases {
            let renderer = ImageRenderer(
                content: RecapStoryCard(
                    images: [swatch, swatch],
                    mealCount: 2,
                    theme: theme,
                    boardPlacements: positions
                )
                .frame(width: RecapStoryCard.size.width, height: RecapStoryCard.size.height)
            )
            XCTAssertNotNil(renderer.uiImage, "\(theme.rawValue) should render")
        }
    }

    @MainActor
    func test_storyCardRendersWithASingleBoardShape() {
        let swatch = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image {
            UIColor.systemPink.setFill()
            $0.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }

        let renderer = ImageRenderer(
            content: RecapStoryCard(
                images: [swatch],
                mealCount: 1
            )
            .frame(width: RecapStoryCard.size.width, height: RecapStoryCard.size.height)
        )
        XCTAssertNotNil(renderer.uiImage)
    }
}
