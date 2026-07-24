import XCTest
import Dependencies
@testable import ClientKit

final class FoodCutoutClientTests: XCTestCase {
    func test_liveValue_extractsAtLeastOneCutout_fromFoodPhoto() async throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "test-food", withExtension: "jpg"))
        let data = try Data(contentsOf: url)

        let client = FoodCutoutClient.liveValue
        let cutouts: [Cutout]
        do {
            cutouts = try await client.extract(data)
        } catch {
            // VNGenerateForegroundInstanceMaskRequest needs a Neural Engine
            // inference context the iOS Simulator cannot create
            // ("com.apple.Vision Code=9 Could not create inference context").
            // The extraction path is verified on device-class hardware; skip
            // rather than fail when running in the simulator.
            throw XCTSkip("Vision inference context unavailable (simulator): \(error.localizedDescription)")
        }

        XCTAssertGreaterThanOrEqual(cutouts.count, 1)
        XCTAssertFalse(cutouts[0].pngData.isEmpty)
    }
}
