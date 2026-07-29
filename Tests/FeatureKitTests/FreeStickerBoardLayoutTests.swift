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

    /// The board now spans the whole screen with the controls floating over it,
    /// so a fresh sticker must land clear of them instead of underneath.
    func test_defaultPointsStartBelowTheFloatingControls() {
        let plain = FreeStickerBoardLayout.defaultPoint(index: 0, width: 393)
        let inset = FreeStickerBoardLayout.defaultPoint(index: 0, width: 393, topInset: 150)

        XCTAssertEqual(inset.y - plain.y, 150, accuracy: 0.001)
        XCTAssertEqual(inset.x, plain.x, accuracy: 0.001)
    }

    /// A sticker may still be dragged up into the chrome; only the default
    /// layout keeps out of it.
    func test_draggingIsNotRestrictedByTheControlInset() {
        let point = FreeStickerBoardLayout.clamped(
            CGPoint(x: 200, y: 0),
            width: 393,
            height: 900
        )
        let halfSide = FreeStickerBoardLayout.itemSide(width: 393) / 2

        XCTAssertLessThan(point.y, 150)
        XCTAssertGreaterThanOrEqual(point.y, halfSide)
    }

    /// An almost-empty canvas should still be a full screen of board, so there is
    /// somewhere to drag a sticker to.
    func test_boardFillsAtLeastTheGivenMinimumHeight() {
        let height = FreeStickerBoardLayout.boardHeight(
            count: 1,
            width: 393,
            placements: [],
            minimum: 780
        )

        XCTAssertEqual(height, 780, accuracy: 0.001)
    }

    func test_boardGrowsPastTheMinimumForStickersPlacedLow() {
        let height = FreeStickerBoardLayout.boardHeight(
            count: 1,
            width: 393,
            placements: [StickerBoardPlacement(xFraction: 0.5, y: 1_200)],
            minimum: 780
        )

        XCTAssertGreaterThan(height, 1_200)
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

    func test_boardFramesHaveStableUniqueStorageValues() {
        XCTAssertEqual(StickerBoardFrame.allCases.count, 4)
        XCTAssertEqual(
            Set(StickerBoardFrame.allCases.map(\.rawValue)).count,
            StickerBoardFrame.allCases.count
        )
        XCTAssertEqual(
            StickerBoardFrame(rawValue: StickerBoardFrame.ticket.rawValue),
            .ticket
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

    func test_scaleAndRotationSnapNearUsefulValues() {
        XCTAssertEqual(FreeStickerBoardLayout.snappedScale(1.04), 1)
        XCTAssertEqual(FreeStickerBoardLayout.snappedScale(1.08), 1.08)
        XCTAssertEqual(FreeStickerBoardLayout.snappedRotation(1.8), 0)
        XCTAssertEqual(FreeStickerBoardLayout.snappedRotation(13.2), 15)
        XCTAssertEqual(FreeStickerBoardLayout.snappedRotation(11), 11)
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
