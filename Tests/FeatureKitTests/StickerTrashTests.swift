import CoreGraphics
import XCTest
@testable import FeatureKit

/// Dropping a sticker on the bin asks to delete it, so the bin's reach has to be
/// generous enough to hit with a fingertip covering it, and nowhere near where
/// stickers normally sit.
final class StickerTrashTests: XCTestCase {
    private let width: CGFloat = 393
    private let height: CGFloat = 800

    func test_binSitsAtTheBottomCentre() {
        let centre = FreeStickerBoardLayout.trashCenter(width: width, height: height)
        XCTAssertEqual(centre.x, width / 2, accuracy: 0.001)
        XCTAssertGreaterThan(centre.y, height * 0.75)
        // Clear of the floating tab bar.
        XCTAssertLessThan(centre.y, height - 96)
    }

    func test_aDropOnTheBinCounts() {
        let centre = FreeStickerBoardLayout.trashCenter(width: width, height: height)
        XCTAssertTrue(FreeStickerBoardLayout.isOverTrash(centre, width: width, height: height))
    }

    func test_aDropJustBesideTheBinStillCounts() {
        let centre = FreeStickerBoardLayout.trashCenter(width: width, height: height)
        let near = CGPoint(x: centre.x + 40, y: centre.y - 20)
        XCTAssertTrue(FreeStickerBoardLayout.isOverTrash(near, width: width, height: height))
    }

    /// The first row of stickers must never be read as a drop on the bin.
    func test_aDropWhereStickersLiveDoesNotCount() {
        let firstSlot = FreeStickerBoardLayout.defaultPoint(index: 0, width: width, topInset: 150)
        XCTAssertFalse(
            FreeStickerBoardLayout.isOverTrash(firstSlot, width: width, height: height)
        )
    }

    func test_aDropAcrossTheBoardDoesNotCount() {
        XCTAssertFalse(
            FreeStickerBoardLayout.isOverTrash(
                CGPoint(x: 20, y: 20), width: width, height: height
            )
        )
    }
}
