import CoreGraphics
import Foundation

/// Geometry for the collection board's motion.
///
/// Deliberately free of SwiftUI and CoreMotion: every number the board animates
/// is a pure function of an index, a tilt, or a gesture, so the feel can be
/// pinned down by tests instead of only by eye on a device.
enum StickerBoardMotion {

    /// Ceiling on how far a sticker drifts, so a tilted board never looks torn.
    static let maxLean: CGFloat = 14
    /// Ceiling on the lean rotation, in degrees.
    static let maxLeanRotation: Double = 6
    static let maxReleaseVelocity: Double = 14

    // MARK: - Gravity lean

    /// A stable 0...1 value per tile. Drives the stagger that keeps the wall from
    /// moving as one slab — the flaw that made the old uniform parallax invisible.
    static func phase(index: Int) -> CGFloat {
        CGFloat((index &* 37) % 11) / 10
    }

    /// How far tile `index` drifts at the given tilt.
    static func lean(index: Int, tiltX: Double, tiltY: Double) -> CGSize {
        let amplitude = 4 + phase(index: index) * (maxLean - 4)
        return CGSize(
            width: CGFloat(tiltX) * amplitude,
            height: CGFloat(tiltY) * amplitude * 0.6
        )
    }

    /// How far tile `index` turns at the given roll, in degrees.
    static func leanRotation(index: Int, tiltX: Double) -> Double {
        let amplitude = 2 + Double(phase(index: index)) * (maxLeanRotation - 2)
        return tiltX * amplitude
    }

    // MARK: - Neighbour repulsion

    /// How far a tile steps aside for the sticker being held, in points.
    ///
    /// Distances are in grid cells, not screen points, which keeps this testable
    /// and spares every tile from reporting its frame back up the view tree.
    static func repulsion(
        heldCell: CGPoint,
        cell: CGPoint,
        radius: CGFloat,
        strength: CGFloat
    ) -> CGSize {
        let dx = cell.x - heldCell.x
        let dy = cell.y - heldCell.y
        let distance = sqrt(dx * dx + dy * dy)
        // The held tile sits at zero distance; normalising it would yield NaN,
        // and a NaN offset blanks the view.
        guard distance > 0.001, distance < radius else { return .zero }
        let falloff = 1 - distance / radius
        let push = falloff * falloff * strength
        return CGSize(width: dx / distance * push, height: dy / distance * push)
    }

    // MARK: - Release

    /// Initial spring velocity for a released sticker.
    ///
    /// `interpolatingSpring(initialVelocity:)` measures velocity in fractions of
    /// the remaining distance per second, so this is the flick's speed over the
    /// distance left to travel home. A flick overshoots and settles; a slow
    /// release just eases back.
    static func releaseVelocity(velocity: CGSize, translation: CGSize) -> Double {
        let distance = hypot(translation.width, translation.height)
        // A press that never travelled has nowhere to spring back from.
        guard distance > 0.5 else { return 0 }
        let speed = hypot(velocity.width, velocity.height)
        return min(Double(speed / distance), maxReleaseVelocity)
    }

    // MARK: - Spill

    /// Stagger for the pull-to-spill animation, in seconds. Capped so a large
    /// collection does not stretch a refresh into a wait.
    static func spillDelay(index: Int, step: Double = 0.03, cap: Double = 0.42) -> Double {
        min(Double(max(0, index)) * step, cap)
    }

    // MARK: - Tilt to browse

    /// The column the board leans toward, once the tilt is decisive.
    static func revealedColumn(tiltX: Double, columnCount: Int, threshold: Double) -> Int? {
        guard columnCount > 0, abs(tiltX) >= threshold else { return nil }
        return tiltX > 0 ? columnCount - 1 : 0
    }
}
