import SwiftUI
import CoreMotion

@MainActor
@Observable
public final class ParallaxMotion {
    public private(set) var tiltX: Double = 0   // roll, normalized -1...1
    public private(set) var tiltY: Double = 0   // pitch, normalized -1...1

    @ObservationIgnored private let manager = CMMotionManager()
    /// The angle the device rested at when tracking began, so tilt is measured
    /// from however the user happens to be holding it.
    @ObservationIgnored private var restingPitch: Double?
    @ObservationIgnored private var restingRoll: Double?

    public init() {}

    public func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            let restingRoll = self.restingRoll ?? m.attitude.roll
            let restingPitch = self.restingPitch ?? m.attitude.pitch
            self.restingRoll = restingRoll
            self.restingPitch = restingPitch

            let targetX = StickerBoardMotion.normalizedTilt(
                m.attitude.roll, reference: restingRoll
            )
            let targetY = StickerBoardMotion.normalizedTilt(
                m.attitude.pitch, reference: restingPitch
            )
            // Low-pass the 30Hz sensor stream. Raw attitude values make the
            // sticker edges shimmer even while a device is held still.
            self.tiltX += (targetX - self.tiltX) * 0.16
            self.tiltY += (targetY - self.tiltY) * 0.16
        }
    }

    public func stop() {
        manager.stopDeviceMotionUpdates()
        restingRoll = nil
        restingPitch = nil
        tiltX = 0
        tiltY = 0
    }
}
