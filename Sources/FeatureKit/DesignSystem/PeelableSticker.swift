import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Tracks which sticker is currently under a finger, so the others can step
/// aside for it. One instance per board.
@MainActor
@Observable
public final class PeelCoordinator {
    /// Grid cell (column, row) of the held sticker, or nil when nothing is held.
    public private(set) var heldCell: CGPoint?

    public init() {}

    func hold(_ cell: CGPoint) { heldCell = cell }
    func release() { heldCell = nil }
}

/// Makes a sticker feel physically touchable: hold it to lift and enlarge it,
/// keep moving to peel it off the board, let go and it springs back into its
/// slot carrying the flick's momentum.
///
/// Press and drag are one sequenced gesture on purpose. A bare `DragGesture`
/// inside the board's vertical `ScrollView` fights the scroll; requiring the
/// press first hands the touch to the sticker only once the user clearly means
/// to grab it.
struct PeelableSticker: ViewModifier {
    /// This sticker's (column, row).
    let cell: CGPoint
    let coordinator: PeelCoordinator
    let enabled: Bool

    @State private var offset: CGSize = .zero
    @State private var isHeld = false
    @State private var isDragging = false

    private static let pushRadius: CGFloat = 1.9
    private static let pushStrength: CGFloat = 17

    /// How far this tile is shoved aside by whichever sticker is being held.
    private var push: CGSize {
        guard let heldCell = coordinator.heldCell else { return .zero }
        return StickerBoardMotion.repulsion(
            heldCell: heldCell,
            cell: cell,
            radius: Self.pushRadius,
            strength: Self.pushStrength
        )
    }

    private var scale: CGFloat {
        if isDragging { return 1.1 }   // peeled off, following the finger
        if isHeld { return 1.3 }       // held still — the look-closer peek
        return 1
    }

    /// Leans into the drag, the way a peeled sticker trails behind your finger.
    private var dragTilt: Double {
        guard isDragging else { return 0 }
        return max(-11, min(11, Double(offset.width) / 9))
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(dragTilt))
            .offset(x: offset.width + push.width, y: offset.height + push.height)
            .shadow(
                color: Color(.sRGB, red: 120 / 255, green: 90 / 255, blue: 150 / 255, opacity: isHeld ? 0.3 : 0),
                radius: isHeld ? 20 : 0,
                x: 0,
                y: isHeld ? 15 : 0
            )
            .zIndex(isHeld ? 20 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.68), value: isHeld)
            .animation(.spring(response: 0.3, dampingFraction: 0.68), value: isDragging)
            // Keyed on `push` only, so a neighbour glides aside while the held
            // sticker still tracks the finger one-to-one.
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: push)
            // Simultaneous keeps the native context menu available on a
            // stationary long press. The peel only lifts after actual travel.
            .simultaneousGesture(peelGesture)
    }

    private var peelGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard enabled else { return }
                switch value {
                case .first(true):
                    break
                case let .second(true, drag):
                    if let drag, hypot(drag.translation.width, drag.translation.height) > 4 {
                        lift()
                        isDragging = true
                        offset = drag.translation
                    }
                default:
                    // The gesture never completed or was taken away mid-flight;
                    // don't leave the sticker stranded off the board.
                    if isHeld { settle(releaseVelocity: 0) }
                }
            }
            .onEnded { value in
                guard enabled, isHeld else { return }
                var velocity: Double = 0
                if case let .second(true, drag) = value, let drag {
                    velocity = StickerBoardMotion.releaseVelocity(
                        velocity: drag.velocity,
                        translation: drag.translation
                    )
                }
                settle(releaseVelocity: velocity)
            }
    }

    private func lift() {
        guard !isHeld else { return }
        isHeld = true
        coordinator.hold(cell)
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    private func settle(releaseVelocity: Double) {
        isHeld = false
        isDragging = false
        coordinator.release()
        withAnimation(
            .interpolatingSpring(
                mass: 0.42,
                stiffness: 190,
                damping: 13,
                initialVelocity: releaseVelocity
            )
        ) {
            offset = .zero
        }
    }
}

extension View {
    /// Keeps a stationary long press for the native menu; hold then move to peel.
    func peelable(
        cell: CGPoint,
        coordinator: PeelCoordinator,
        enabled: Bool = true
    ) -> some View {
        modifier(PeelableSticker(cell: cell, coordinator: coordinator, enabled: enabled))
    }
}
