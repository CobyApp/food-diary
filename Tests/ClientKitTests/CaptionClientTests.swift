import XCTest
@testable import ClientKit

final class CaptionClientTests: XCTestCase {
    func test_tidy_stripsQuotesAndWhitespace() {
        XCTAssertEqual(CaptionClient.tidy("  \"이번 주도 잘 먹었어요\" \n"), "이번 주도 잘 먹었어요")
        XCTAssertEqual(CaptionClient.tidy("「おいしい一週間」"), "おいしい一週間")
    }

    func test_tidy_keepsOnlyTheFirstLine() {
        XCTAssertEqual(CaptionClient.tidy("한 줄 요약\n설명이 더 붙었어요"), "한 줄 요약")
    }

    func test_tidy_rejectsEmptyOrOverlongAnswers() {
        XCTAssertNil(CaptionClient.tidy("   "))
        XCTAssertNil(CaptionClient.tidy(String(repeating: "가", count: 41)))
    }

    func test_languageName_mapsUILanguages() {
        XCTAssertEqual(CaptionClient.languageName(for: "ko"), "Korean")
        XCTAssertEqual(CaptionClient.languageName(for: "ja-JP"), "Japanese")
        XCTAssertEqual(CaptionClient.languageName(for: "zh-Hans"), "Simplified Chinese")
        XCTAssertEqual(CaptionClient.languageName(for: "fr"), "English")
    }
}
