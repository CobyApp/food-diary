import CoreGraphics
import XCTest
@testable import FeatureKit

/// A recap should look like the board it came from. Without this, all four boards
/// produced the same card with a different background.
final class RecapCollageStyleTests: XCTestCase {

    func test_eachBoardArrangesItsRecapDifferently() {
        let styles = StickerBoardTheme.allCases.map(\.recapStyle)
        XCTAssertEqual(Set(styles.map(\.tiltScale)).count, styles.count)
    }

    /// The diary board is the tidy one: rows straight, no wave.
    func test_theDiaryBoardBarelyTiltsAndDoesNotWave() {
        let diary = StickerBoardTheme.creamDiary.recapStyle
        XCTAssertLessThan(diary.tiltScale, 0.5)
        XCTAssertEqual(diary.waveAmplitude, 0)
        XCTAssertEqual(diary.waveOffset(column: 1, canvasHeight: 400), 0)
    }

    /// Pop leans hardest and runs largest.
    func test_thePopBoardLeansMostAndRunsLargest() {
        let pop = StickerBoardTheme.lavenderPop.recapStyle
        for other in StickerBoardTheme.allCases.filter({ $0 != .lavenderPop }) {
            XCTAssertGreaterThan(pop.tiltScale, other.recapStyle.tiltScale)
            XCTAssertGreaterThanOrEqual(pop.sizeScale, other.recapStyle.sizeScale)
        }
    }

    /// Soda's columns ride a wave, so neighbouring columns sit at different heights.
    func test_theSodaBoardOffsetsNeighbouringColumns() {
        let soda = StickerBoardTheme.sodaBlue.recapStyle
        let first = soda.waveOffset(column: 0, canvasHeight: 400)
        let second = soda.waveOffset(column: 1, canvasHeight: 400)
        XCTAssertNotEqual(first, second)
    }

    /// However far a sticker drifts, it must stay on the card.
    func test_theWaveNeverPushesAStickerOffTheCard() {
        for theme in StickerBoardTheme.allCases {
            for column in 0..<3 {
                let offset = theme.recapStyle.waveOffset(column: column, canvasHeight: 400)
                XCTAssertLessThanOrEqual(abs(offset), 400 * 0.12)
            }
        }
    }
}
