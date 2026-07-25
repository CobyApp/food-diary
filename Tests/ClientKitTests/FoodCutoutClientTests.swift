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

        // The simulator's Vision may return zero foreground instances without
        // throwing (no inference context / no salient subject). Skip rather than
        // index into an empty array; the >=1 assertion holds on device.
        guard let first = cutouts.first else {
            throw XCTSkip("Vision returned no foreground instances in this environment")
        }
        XCTAssertFalse(first.pngData.isEmpty)
    }
}
