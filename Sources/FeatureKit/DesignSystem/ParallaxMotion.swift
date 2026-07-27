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
            // Clamp to a gentle range so the wall drifts subtly.
            self.tiltX = max(-1, min(1, m.attitude.roll / 0.8))
            self.tiltY = max(-1, min(1, m.attitude.pitch / 0.8))
        }
    }

    public func stop() { manager.stopDeviceMotionUpdates() }
}

public extension View {
    func parallax(_ strength: CGFloat, motion: ParallaxMotion) -> some View {
        offset(x: CGFloat(motion.tiltX) * strength, y: CGFloat(motion.tiltY) * strength)
            .shadow(
                color: Color(.sRGB, red: 150 / 255, green: 120 / 255, blue: 180 / 255, opacity: 0.10),
                radius: 8,
                x: CGFloat(-motion.tiltX) * strength * 0.6,
                y: CGFloat(-motion.tiltY) * strength * 0.6
            )
    }
}
