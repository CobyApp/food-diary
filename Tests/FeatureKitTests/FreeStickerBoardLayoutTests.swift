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

    func test_boardThemesHaveStableUniqueStorageValues() {
        XCTAssertEqual(StickerBoardTheme.allCases.count, 4)
        XCTAssertEqual(
            Set(StickerBoardTheme.allCases.map(\.rawValue)).count,
            StickerBoardTheme.allCases.count
        )
        XCTAssertEqual(
            StickerBoardTheme(rawValue: StickerBoardTheme.lavenderPop.rawValue),
            .lavenderPop
        )
    }

    func test_oldSavedPlacementDecodesWithoutTransformValues() throws {
        let data = Data(#"{"xFraction":0.4,"y":180}"#.utf8)
        let placement = try JSONDecoder().decode(StickerBoardPlacement.self, from: data)

        XCTAssertEqual(placement.displayScale, 1)
        XCTAssertNil(placement.rotation)
    }

    func test_scaleAndRotationAreKeptInsideSafeRanges() {
        XCTAssertEqual(FreeStickerBoardLayout.clampedScale(0.1), 0.68)
        XCTAssertEqual(FreeStickerBoardLayout.clampedScale(4), 1.5)
        XCTAssertEqual(FreeStickerBoardLayout.normalizedRotation(450), 90)
        XCTAssertEqual(FreeStickerBoardLayout.normalizedRotation(-450), -90)
    }

    func test_largeStickerCenterIsClampedFurtherFromTheEdge() {
        let regular = FreeStickerBoardLayout.clamped(
            CGPoint(x: 0, y: 100),
            width: 354,
            height: 500
        )
        let large = FreeStickerBoardLayout.clamped(
            CGPoint(x: 0, y: 100),
            width: 354,
            height: 500,
            scale: 1.5
        )

        XCTAssertGreaterThan(large.x, regular.x)
    }
}
