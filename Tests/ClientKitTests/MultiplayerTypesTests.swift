import XCTest
@testable import ClientKit

final class MultiplayerTypesTests: XCTestCase {
    func test_message_menu_codableRoundTrip() throws {
        let pick = MenuPick(playerID: "p1", playerName: "코비", thumbnail: Data([1, 2, 3]),
                            tags: ["존맛"], placeName: "라멘집", address: "후쿠오카 1-2")
        let msg = MultiplayerMessage.menu(pick)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(MultiplayerMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
    }

    func test_message_roundResult_codableRoundTrip() throws {
        let msg = MultiplayerMessage.roundResult(winnerID: "p1", leftVotes: 2, rightVotes: 1)
        let data = try JSONEncoder().encode(msg)
        XCTAssertEqual(try JSONDecoder().decode(MultiplayerMessage.self, from: data), msg)
    }

    func test_message_bracketAndVote_codableRoundTrip() throws {
        for msg in [MultiplayerMessage.bracket(["a", "b"]), .pair(index: 2), .vote(candidateID: "b"), .champion("a")] {
            let data = try JSONEncoder().encode(msg)
            XCTAssertEqual(try JSONDecoder().decode(MultiplayerMessage.self, from: data), msg)
        }
    }
}
