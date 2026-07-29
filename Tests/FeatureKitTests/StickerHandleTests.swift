import CoreGraphics
import XCTest
@testable import FeatureKit

/// A pinch needs two fingers inside a ~110pt sticker, which is why scaling and
/// rotating moved to a one-finger corner handle. These pin down the geometry.
final class StickerHandleTests: XCTestCase {
    private let center = CGPoint(x: 200, y: 300)
    private let side: CGFloat = 110

    func test_handleSitsAtTheCornerWhenUntouched() {
        let handle = FreeStickerBoardLayout.handlePosition(
            center: center, side: side, scale: 1, rotationDegrees: 0
        )
        XCTAssertEqual(handle.x, center.x + side / 2, accuracy: 0.001)
        XCTAssertEqual(handle.y, center.y + side / 2, accuracy: 0.001)
    }

    func test_handleFollowsScale() {
        let handle = FreeStickerBoardLayout.handlePosition(
            center: center, side: side, scale: 1.5, rotationDegrees: 0
        )
        XCTAssertEqual(handle.x, center.x + side * 1.5 / 2, accuracy: 0.001)
    }

    /// Turning the sticker a quarter turn puts the bottom-trailing corner where
    /// the bottom-leading one used to be.
    func test_handleTurnsWithTheSticker() {
        let handle = FreeStickerBoardLayout.handlePosition(
            center: center, side: side, scale: 1, rotationDegrees: 90
        )
        XCTAssertEqual(handle.x, center.x - side / 2, accuracy: 0.001)
        XCTAssertEqual(handle.y, center.y + side / 2, accuracy: 0.001)
    }

    // MARK: - Reading a drag back

    /// Leaving the handle where it already sits must not resize or turn anything.
    func test_handleAtItsRestingCornerMeansNoChange() {
        let handle = FreeStickerBoardLayout.handlePosition(
            center: center, side: side, scale: 1, rotationDegrees: 0
        )
        let result = FreeStickerBoardLayout.handleTransform(
            handle: handle, center: center, side: side
        )
        XCTAssertEqual(result.scale, 1, accuracy: 0.001)
        XCTAssertEqual(result.rotation, 0, accuracy: 0.001)
    }

    func test_draggingTheHandleOutwardGrowsTheSticker() {
        let near = FreeStickerBoardLayout.handleTransform(
            handle: CGPoint(x: center.x + 50, y: center.y + 50), center: center, side: side
        )
        let far = FreeStickerBoardLayout.handleTransform(
            handle: CGPoint(x: center.x + 70, y: center.y + 70), center: center, side: side
        )
        XCTAssertGreaterThan(far.scale, near.scale)
    }

    func test_scaleFromTheHandleStaysInsideTheAllowedRange() {
        let huge = FreeStickerBoardLayout.handleTransform(
            handle: CGPoint(x: center.x + 900, y: center.y + 900), center: center, side: side
        )
        let tiny = FreeStickerBoardLayout.handleTransform(
            handle: center, center: center, side: side
        )
        XCTAssertEqual(huge.scale, FreeStickerBoardLayout.scaleRange.upperBound)
        XCTAssertEqual(tiny.scale, FreeStickerBoardLayout.scaleRange.lowerBound)
    }

    func test_swingingTheHandleTurnsTheSticker() {
        // Straight below the centre is a quarter turn from the resting corner.
        let result = FreeStickerBoardLayout.handleTransform(
            handle: CGPoint(x: center.x, y: center.y + 78), center: center, side: side
        )
        XCTAssertEqual(result.rotation, 45, accuracy: 0.5)
    }

    /// Handle and centre on the same point would divide by zero.
    func test_handleTransformSurvivesAZeroSizedSticker() {
        let result = FreeStickerBoardLayout.handleTransform(
            handle: center, center: center, side: 0
        )
        XCTAssertEqual(result.scale, 1)
        XCTAssertEqual(result.rotation, 0)
    }
}
