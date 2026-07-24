import XCTest
@testable import ClientKit

final class ImageStoreTests: XCTestCase {
    func test_save_thenLoad_returnsSameBytes() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ImageStore.disk(directory: dir)
        let bytes = Data([0x89, 0x50, 0x4E, 0x47])

        let name = try store.save(bytes)
        XCTAssertEqual(store.load(name), bytes)

        try store.delete(name)
        XCTAssertNil(store.load(name))
    }
}
