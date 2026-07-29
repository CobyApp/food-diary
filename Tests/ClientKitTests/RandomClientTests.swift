import XCTest
import Models
@testable import ClientKit

final class RandomClientTests: XCTestCase {
    private func snap(_ id: String) -> FoodEntrySnapshot {
        FoodEntrySnapshot(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000\(id)")!,
                       fileName: "\(id).png", eatenAt: Date(timeIntervalSince1970: 0), label: nil)
    }

    func test_liveShuffled_preservesElements() {
        let items = [snap("01"), snap("02"), snap("03")]
        let out = RandomClient.liveValue.shuffled(items)
        XCTAssertEqual(out.count, 3)
        XCTAssertEqual(Set(out.map(\.id)), Set(items.map(\.id)))
    }

    func test_livePick_returnsMemberOrNil() {
        XCTAssertNil(RandomClient.liveValue.pick([]))
        let items = [snap("01")]
        XCTAssertEqual(RandomClient.liveValue.pick(items)?.id, items[0].id)
    }
}
