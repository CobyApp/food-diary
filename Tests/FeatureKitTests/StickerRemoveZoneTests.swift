import CoreGraphics
import XCTest
@testable import FeatureKit

/// Dropping a sticker on the zone takes it off the board, so the zone's reach has
/// to be generous enough to hit with a fingertip covering it, and nowhere near
/// where stickers normally sit.
final class StickerTrashTests: XCTestCase {
    private let width: CGFloat = 393
    private let height: CGFloat = 800

    func test_zoneSitsAtTheBottomCentre() {
        let centre = FreeStickerBoardLayout.removeZoneCenter(width: width, height: height)
        XCTAssertEqual(centre.x, width / 2, accuracy: 0.001)
        XCTAssertGreaterThan(centre.y, height * 0.75)
        // Clear of the floating tab bar.
        XCTAssertLessThan(centre.y, height - 96)
    }

    func test_aDropOnTheZoneCounts() {
        let centre = FreeStickerBoardLayout.removeZoneCenter(width: width, height: height)
        XCTAssertTrue(FreeStickerBoardLayout.isOverRemoveZone(centre, width: width, height: height))
    }

    func test_aDropJustBesideTheZoneStillCounts() {
        let centre = FreeStickerBoardLayout.removeZoneCenter(width: width, height: height)
        let near = CGPoint(x: centre.x + 40, y: centre.y - 20)
        XCTAssertTrue(FreeStickerBoardLayout.isOverRemoveZone(near, width: width, height: height))
    }

    /// The first row of stickers must never be read as a drop on the zone.
    func test_aDropWhereStickersLiveDoesNotCount() {
        let firstSlot = FreeStickerBoardLayout.defaultPoint(index: 0, width: width, topInset: 150)
        XCTAssertFalse(
            FreeStickerBoardLayout.isOverRemoveZone(firstSlot, width: width, height: height)
        )
    }

    func test_aDropAcrossTheBoardDoesNotCount() {
        XCTAssertFalse(
            FreeStickerBoardLayout.isOverRemoveZone(
                CGPoint(x: 20, y: 20), width: width, height: height
            )
        )
    }
}
