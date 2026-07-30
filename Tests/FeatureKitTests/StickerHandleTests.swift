import CoreGraphics
import XCTest
@testable import FeatureKit

/// A pinch needs two fingers inside a ~110pt sticker, which is why scaling and
/// rotating moved to a one-finger corner handle. The handle reads the *change* in
/// the finger's position, never its absolute position — these pin that down.
final class StickerHandleTests: XCTestCase {
    private let center = CGPoint(x: 200, y: 300)
    private let side: CGFloat = 110

    // MARK: - Where the handle sits

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

    // MARK: - Scaling by how far the finger moved

    /// The bug this replaced: grabbing the handle a little off-centre used to
    /// resize the sticker before the finger had moved at all.
    func test_grabbingWithoutMovingChangesNothing() {
        let scale = FreeStickerBoardLayout.scaled(
            grabScale: 1.2, grabDistance: 70, distance: 70
        )
        XCTAssertEqual(scale, 1.2, accuracy: 0.0001)
    }

    func test_movingTheHandleOutwardGrowsTheStickerProportionally() {
        let scale = FreeStickerBoardLayout.scaled(
            grabScale: 1, grabDistance: 50, distance: 60
        )
        XCTAssertEqual(scale, 1.2, accuracy: 0.0001)
    }

    func test_movingTheHandleInwardShrinksTheSticker() {
        let scale = FreeStickerBoardLayout.scaled(
            grabScale: 1, grabDistance: 100, distance: 80
        )
        XCTAssertEqual(scale, 0.8, accuracy: 0.0001)
    }

    func test_scaleStaysInsideTheAllowedRange() {
        XCTAssertEqual(
            FreeStickerBoardLayout.scaled(grabScale: 1, grabDistance: 10, distance: 900),
            FreeStickerBoardLayout.scaleRange.upperBound
        )
        XCTAssertEqual(
            FreeStickerBoardLayout.scaled(grabScale: 1, grabDistance: 900, distance: 1),
            FreeStickerBoardLayout.scaleRange.lowerBound
        )
    }

    /// A grab right on the centre has no distance to divide by.
    func test_aGrabAtTheCentreDoesNotDivideByZero() {
        let scale = FreeStickerBoardLayout.scaled(
            grabScale: 1.1, grabDistance: 0, distance: 40
        )
        XCTAssertEqual(scale, 1.1, accuracy: 0.0001)
    }

    // MARK: - Rotating by how far the finger swung

    func test_swingingTheHandleTurnsTheStickerByTheSameAmount() {
        XCTAssertEqual(FreeStickerBoardLayout.angleDelta(from: 45, to: 90), 45, accuracy: 0.0001)
        XCTAssertEqual(FreeStickerBoardLayout.angleDelta(from: 90, to: 45), -45, accuracy: 0.0001)
    }

    /// Swinging past due west flips atan2 from 179° to -179°; subtracting raw
    /// angles there would spin the sticker most of a full turn the wrong way.
    func test_crossingTheAngleSeamTakesTheShortWayRound() {
        XCTAssertEqual(FreeStickerBoardLayout.angleDelta(from: 179, to: -179), 2, accuracy: 0.0001)
        XCTAssertEqual(FreeStickerBoardLayout.angleDelta(from: -179, to: 179), -2, accuracy: 0.0001)
    }

    func test_noSwingIsNoRotation() {
        XCTAssertEqual(FreeStickerBoardLayout.angleDelta(from: 33, to: 33), 0, accuracy: 0.0001)
    }

    // MARK: - Reading a point

    func test_angleIsMeasuredFromTheCentre() {
        XCTAssertEqual(
            FreeStickerBoardLayout.angle(of: CGPoint(x: center.x + 10, y: center.y), from: center),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            FreeStickerBoardLayout.angle(of: CGPoint(x: center.x, y: center.y + 10), from: center),
            90,
            accuracy: 0.0001
        )
    }

    func test_distanceIsFlooredSoItCanAlwaysBeDividedBy() {
        XCTAssertGreaterThanOrEqual(
            FreeStickerBoardLayout.distance(from: center, to: center),
            1
        )
    }
}
