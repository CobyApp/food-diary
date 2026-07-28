import CoreGraphics
import XCTest
@testable import FeatureKit

final class FreeStickerBoardLayoutTests: XCTestCase {
    func test_defaultPointsFillThreeColumnsWithoutLeavingTheBoard() {
        let width: CGFloat = 354
        let side = FreeStickerBoardLayout.itemSide(width: width)

        for index in 0..<12 {
            let point = FreeStickerBoardLayout.defaultPoint(index: index, width: width)
            XCTAssertGreaterThanOrEqual(point.x, side / 2)
            XCTAssertLessThanOrEqual(point.x, width - side / 2)
        }
    }

    func test_draggedPositionIsClampedInsideTheBoard() {
        let point = FreeStickerBoardLayout.clamped(
            CGPoint(x: -500, y: 9_000),
            width: 354,
            height: 520
        )
        let halfSide = FreeStickerBoardLayout.itemSide(width: 354) / 2

        XCTAssertGreaterThanOrEqual(point.x, halfSide)
        XCTAssertLessThanOrEqual(point.y, 520 - halfSide)
    }

    func test_savedPlacementRestoresAtTheSameRelativeHorizontalPosition() {
        let original = FreeStickerBoardLayout.placement(
            for: CGPoint(x: 270, y: 220),
            width: 360,
            height: 500
        )
        let restored = FreeStickerBoardLayout.point(
            for: original,
            index: 0,
            width: 320,
            height: 500
        )

        XCTAssertEqual(restored.x / 320, 0.75, accuracy: 0.001)
        XCTAssertEqual(restored.y, 220, accuracy: 0.001)
    }

    func test_boardGrowsToKeepSavedStickerVisible() {
        let placement = StickerBoardPlacement(xFraction: 0.5, y: 720)
        let height = FreeStickerBoardLayout.boardHeight(
            count: 1,
            width: 354,
            placements: [placement]
        )

        XCTAssertGreaterThan(height, 720)
    }
}
