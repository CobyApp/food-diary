import XCTest
import CoreGraphics
@testable import FeatureKit

final class StickerBoardMotionTests: XCTestCase {

    // MARK: - Lean

    /// The bug this whole change exists to fix: every tile used to move by the
    /// same 8pt, so the wall slid as one slab and read as no motion at all.
    func test_leanAmplitudeDiffersBetweenTiles() {
        let tilt = 1.0
        let offsets = (0..<12).map { StickerBoardMotion.lean(index: $0, tiltX: tilt, tiltY: tilt) }
        let widths = Set(offsets.map { ($0.width * 100).rounded() })
        XCTAssertGreaterThan(widths.count, 3, "tiles must lean by different amounts")
    }

    /// Same index, same lean — the stagger is deterministic, not random, so a
    /// re-render never makes the board jump.
    func test_leanIsDeterministic() {
        let a = StickerBoardMotion.lean(index: 7, tiltX: 0.4, tiltY: -0.2)
        let b = StickerBoardMotion.lean(index: 7, tiltX: 0.4, tiltY: -0.2)
        XCTAssertEqual(a, b)
    }

    /// A sticker leaning further than its own tile would tear the grid apart.
    func test_leanStaysWithinBounds() {
        for index in 0..<40 {
            let offset = StickerBoardMotion.lean(index: index, tiltX: 1, tiltY: 1)
            XCTAssertLessThanOrEqual(abs(offset.width), StickerBoardMotion.maxLean)
            XCTAssertLessThanOrEqual(abs(offset.height), StickerBoardMotion.maxLean)
        }
    }

    func test_leanFollowsTiltDirection() {
        let right = StickerBoardMotion.lean(index: 3, tiltX: 0.8, tiltY: 0)
        let left = StickerBoardMotion.lean(index: 3, tiltX: -0.8, tiltY: 0)
        XCTAssertGreaterThan(right.width, 0)
        XCTAssertEqual(left.width, -right.width, accuracy: 0.0001)
    }

    func test_leanRotationVariesAndIsBounded() {
        let angles = (0..<12).map { StickerBoardMotion.leanRotation(index: $0, tiltX: 1) }
        XCTAssertGreaterThan(Set(angles.map { ($0 * 100).rounded() }).count, 3)
        for angle in angles {
            XCTAssertLessThanOrEqual(abs(angle), StickerBoardMotion.maxLeanRotation)
        }
    }

    // MARK: - Neighbour repulsion

    func test_repulsionPushesDirectlyAwayFromHeldCell() {
        let push = StickerBoardMotion.repulsion(
            heldCell: CGPoint(x: 1, y: 1),
            cell: CGPoint(x: 2, y: 1),
            radius: 2,
            strength: 20
        )
        XCTAssertGreaterThan(push.width, 0, "a tile to the right is pushed right")
        XCTAssertEqual(push.height, 0, accuracy: 0.0001)
    }

    func test_repulsionFadesWithDistance() {
        let near = StickerBoardMotion.repulsion(
            heldCell: .zero, cell: CGPoint(x: 1, y: 0), radius: 3, strength: 20
        )
        let far = StickerBoardMotion.repulsion(
            heldCell: .zero, cell: CGPoint(x: 2, y: 0), radius: 3, strength: 20
        )
        XCTAssertGreaterThan(near.width, far.width)
    }

    func test_repulsionIsZeroAtAndBeyondRadius() {
        for x in [3.0, 4.0, 9.0] {
            let push = StickerBoardMotion.repulsion(
                heldCell: .zero, cell: CGPoint(x: x, y: 0), radius: 3, strength: 20
            )
            XCTAssertEqual(push, .zero, "\(x) cells away must not move")
        }
    }

    /// The held tile itself has zero distance; naive normalisation would divide
    /// by zero and hand SwiftUI a NaN offset, which blanks the view.
    func test_repulsionOfHeldCellIsZeroNotNaN() {
        let push = StickerBoardMotion.repulsion(
            heldCell: CGPoint(x: 2, y: 3), cell: CGPoint(x: 2, y: 3), radius: 2, strength: 20
        )
        XCTAssertEqual(push, .zero)
        XCTAssertFalse(push.width.isNaN)
    }

    // MARK: - Release velocity

    /// Fed to `interpolatingSpring(initialVelocity:)`, whose unit is fractions of
    /// the remaining distance per second — so it is speed over distance.
    func test_releaseVelocityScalesWithFlickSpeed() {
        let slow = StickerBoardMotion.releaseVelocity(
            velocity: CGSize(width: 100, height: 0), translation: CGSize(width: 50, height: 0)
        )
        let fast = StickerBoardMotion.releaseVelocity(
            velocity: CGSize(width: 900, height: 0), translation: CGSize(width: 50, height: 0)
        )
        XCTAssertGreaterThan(fast, slow)
    }

    func test_releaseVelocityIsZeroForANegligibleDrag() {
        let v = StickerBoardMotion.releaseVelocity(
            velocity: CGSize(width: 800, height: 800), translation: CGSize(width: 0.2, height: 0.1)
        )
        XCTAssertEqual(v, 0, "a press with no travel should not launch the sticker")
    }

    func test_releaseVelocityIsClamped() {
        let v = StickerBoardMotion.releaseVelocity(
            velocity: CGSize(width: 9000, height: 9000), translation: CGSize(width: 1, height: 1)
        )
        XCTAssertLessThanOrEqual(v, StickerBoardMotion.maxReleaseVelocity)
    }

    // MARK: - Spill

    func test_spillDelayGrowsWithIndexThenSaturates() {
        XCTAssertEqual(StickerBoardMotion.spillDelay(index: 0), 0, accuracy: 0.0001)
        XCTAssertGreaterThan(
            StickerBoardMotion.spillDelay(index: 5),
            StickerBoardMotion.spillDelay(index: 2)
        )
        // A hundred stickers must not stretch the pull-to-refresh into a wait.
        XCTAssertEqual(
            StickerBoardMotion.spillDelay(index: 400),
            StickerBoardMotion.spillDelay(index: 100),
            accuracy: 0.0001
        )
        XCTAssertLessThanOrEqual(StickerBoardMotion.spillDelay(index: 400), 0.5)
    }

    // MARK: - Tilt to browse

    func test_noColumnRevealedBelowThreshold() {
        XCTAssertNil(StickerBoardMotion.revealedSide(tiltX: 0.3, threshold: 0.55))
    }

    func test_tiltRightRevealsTrailingSide() {
        XCTAssertEqual(
            StickerBoardMotion.revealedSide(tiltX: 0.7, threshold: 0.55),
            .trailing
        )
    }

    func test_tiltLeftRevealsLeadingSide() {
        XCTAssertEqual(
            StickerBoardMotion.revealedSide(tiltX: -0.9, threshold: 0.55),
            .leading
        )
    }

    /// Stickers sit anywhere on a freeform board, so a sticker is revealed by
    /// which half it landed in rather than by a grid column.
    func test_onlyStickersOnTheTiltedHalfAreRevealed() {
        XCTAssertTrue(StickerBoardMotion.isRevealed(xFraction: 0.8, side: .trailing))
        XCTAssertFalse(StickerBoardMotion.isRevealed(xFraction: 0.2, side: .trailing))
        XCTAssertTrue(StickerBoardMotion.isRevealed(xFraction: 0.2, side: .leading))
        XCTAssertFalse(StickerBoardMotion.isRevealed(xFraction: 0.8, side: .leading))
    }

    func test_nothingIsRevealedWithoutATilt() {
        XCTAssertFalse(StickerBoardMotion.isRevealed(xFraction: 0.1, side: nil))
        XCTAssertFalse(StickerBoardMotion.isRevealed(xFraction: 0.9, side: nil))
    }

    // MARK: - Tilt normalisation

    /// A phone is read at an angle, so pitch rests well away from zero. Without
    /// a reference the board would sit permanently shoved to one side.
    func test_tiltIsMeasuredRelativeToHowTheDeviceIsHeld() {
        let resting = StickerBoardMotion.normalizedTilt(0.9, reference: 0.9)
        XCTAssertEqual(resting, 0, accuracy: 0.0001)
    }

    func test_tiltIsClampedToUnitRange() {
        XCTAssertEqual(StickerBoardMotion.normalizedTilt(9, reference: 0), 1, accuracy: 0.0001)
        XCTAssertEqual(StickerBoardMotion.normalizedTilt(-9, reference: 0), -1, accuracy: 0.0001)
    }

    func test_tiltGrowsWithDeviationFromTheReference() {
        let small = StickerBoardMotion.normalizedTilt(0.1, reference: 0)
        let large = StickerBoardMotion.normalizedTilt(0.4, reference: 0)
        XCTAssertGreaterThan(large, small)
    }
}
