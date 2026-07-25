import XCTest
import SwiftUI
@testable import FeatureKit

final class AppColorTests: XCTestCase {
    func test_colorHex_parsesRGBChannels() throws {
        let ui = UIColor(Color(hex: 0x8FBEEA))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Double(r), Double(0x8F) / 255, accuracy: 0.01)
        XCTAssertEqual(Double(g), Double(0xBE) / 255, accuracy: 0.01)
        XCTAssertEqual(Double(b), Double(0xEA) / 255, accuracy: 0.01)
        XCTAssertEqual(Double(a), 1.0, accuracy: 0.01)
    }

    func test_stickerTint_rotatesThroughAllCases() {
        XCTAssertEqual(StickerTint.rotating(0), StickerTint.allCases[0])
        XCTAssertEqual(StickerTint.rotating(StickerTint.allCases.count),
                       StickerTint.allCases[0])
    }
}
