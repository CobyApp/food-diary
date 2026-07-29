import XCTest
@testable import Models

final class TagNameTests: XCTestCase {

    // MARK: - Normalising

    func test_surroundingWhitespaceIsTrimmed() {
        XCTAssertEqual(TagName.normalize("  라멘  "), "라멘")
    }

    /// People type tags with a hash; the hash is punctuation, not part of the name.
    func test_leadingHashesAreStripped() {
        XCTAssertEqual(TagName.normalize("#라멘"), "라멘")
        XCTAssertEqual(TagName.normalize("## 매운맛"), "매운맛")
    }

    func test_innerWhitespaceCollapsesToOneSpace() {
        XCTAssertEqual(TagName.normalize("매운   라멘"), "매운 라멘")
    }

    func test_blankInputIsNotATag() {
        XCTAssertNil(TagName.normalize(""))
        XCTAssertNil(TagName.normalize("   "))
        XCTAssertNil(TagName.normalize("#"))
        XCTAssertNil(TagName.normalize("\n \t"))
    }

    func test_overlongNamesAreCappedSoTheyStillFitAChip() {
        let name = TagName.normalize(String(repeating: "가", count: 40))
        XCTAssertEqual(name?.count, TagName.maxLength)
    }

    // MARK: - Comparing

    func test_tagsDifferingOnlyInCaseAreTheSameTag() {
        XCTAssertTrue(TagName.isSame("Ramen", "ramen"))
        XCTAssertFalse(TagName.isSame("라멘", "우동"))
    }

    // MARK: - Cleaning a picked list

    func test_cleanedKeepsPickOrderAndDropsRepeats() {
        XCTAssertEqual(
            TagName.cleaned(["라멘", " 우동 ", "#라멘", ""]),
            ["라멘", "우동"]
        )
    }

    /// Same word, different capitalisation, one tag — and the first spelling wins.
    func test_cleanedTreatsACaseVariantAsARepeat() {
        XCTAssertEqual(TagName.cleaned(["Ramen", "RAMEN", "ramen"]), ["Ramen"])
    }

    func test_cleanedDropsBlanksEntirely() {
        XCTAssertEqual(TagName.cleaned(["", "  ", "#"]), [])
    }

    // MARK: - Colour

    /// Hashing is seeded per process, so a hash-based colour would change on every
    /// launch. The same tag must keep its colour.
    func test_tintIsStableForTheSameName() {
        let first = TagName.tintIndex(for: "라멘", paletteCount: 5)
        let second = TagName.tintIndex(for: "라멘", paletteCount: 5)
        XCTAssertEqual(first, second)
    }

    func test_tintIgnoresCase() {
        XCTAssertEqual(
            TagName.tintIndex(for: "Ramen", paletteCount: 5),
            TagName.tintIndex(for: "ramen", paletteCount: 5)
        )
    }

    func test_tintStaysInsideThePalette() {
        for name in ["라멘", "우동", "🍜", "a", "매운 라멘"] {
            let index = TagName.tintIndex(for: name, paletteCount: 4)
            XCTAssertTrue((0..<4).contains(index), "\(name) produced \(index)")
        }
    }

    func test_tintHandlesAnEmptyPaletteWithoutDividingByZero() {
        XCTAssertEqual(TagName.tintIndex(for: "라멘", paletteCount: 0), 0)
    }
}
