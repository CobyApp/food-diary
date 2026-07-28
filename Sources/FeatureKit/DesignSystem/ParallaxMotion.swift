import SwiftUI
import CoreMotion

@MainActor
@Observable
public final class ParallaxMotion {
    public private(set) var tiltX: Double = 0   // roll, normalized -1...1
    public private(set) var tiltY: Double = 0   // pitch, normalized -1...1

    @ObservationIgnored private let manager = CMMotionManager()

    public init() {}

    public func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            let targetX = max(-1, min(1, m.attitude.roll / 0.8))
            let targetY = max(-1, min(1, m.attitude.pitch / 0.8))
            // Low-pass the 30Hz sensor stream. Raw attitude values make the
            // sticker edges shimmer even while a device is held still.
            self.tiltX += (targetX - self.tiltX) * 0.16
            self.tiltY += (targetY - self.tiltY) * 0.16
        }
    }

    public func stop() {
        manager.stopDeviceMotionUpdates()
        tiltX = 0
        tiltY = 0
    }
}
