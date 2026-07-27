import ComposableArchitecture
import Models
import SwiftUI

public struct RouletteView: View {
    /// Shared by the wheel spin animation and the reveal delay so they can never drift apart.
    private let spinDuration: TimeInterval = 1.6

    @Bindable var store: StoreOf<RouletteFeature>
    @State private var revealResult = false
    @State private var wheelRotation: Double = 0
    @State private var glow = false
    @State private var winnerPulse = false

    public init(store: StoreOf<RouletteFeature>) { self.store = store }

    // A wheel slice of the reel so the winner (always `reel.last`) is included.
    private var wheelSlice: [CutoutSnapshot] { Array(store.reel.suffix(8)) }
    private var winnerSliceIndex: Int? {
        guard let landing = store.landingIndex else { return nil }
        let start = max(store.reel.count - wheelSlice.count, 0)
        let idx = landing - start
        return wheelSlice.indices.contains(idx) ? idx : nil
    }
    private var segmentAngle: Double { 360.0 / Double(max(wheelSlice.count, 1)) }

    public var body: some View {
        ZStack {
            PaperBackground()
            if let result = store.result, revealResult {
                ResultCard(
                    cutout: result,
                    info: store.resultInfo,
                    onAgain: {
                        revealResult = false
                        wheelRotation = 0
                        winnerPulse = false
                        store.send(.playAgain)
                    },
                    onClose: { store.send(.close) }
                )
            } else {
                VStack(spacing: 20) {
                    VStack(spacing: 5) {
                        Text("스티커 룰렛").font(.appDisplay).foregroundStyle(.appInk)
                        Text("멈추는 순간의 누끼가 오늘 메뉴")
                            .font(.appBody).foregroundStyle(.appMuted)
                    }

                    ZStack {
                        ForEach(Array(wheelSlice.enumerated()), id: \.offset) { index, cutout in
                            let start = Double(index) * segmentAngle - 90
                            Wedge(startAngle: .degrees(start), endAngle: .degrees(start + segmentAngle))
                                .fill([Color.appPink, .appButter, .appBlue, .appLavender][index % 4])
                                .overlay {
                                    CutoutImage(fileName: cutout.fileName)
                                        .frame(width: 52, height: 52)
                                        .offset(y: -74)
                                        .rotationEffect(.degrees(start + segmentAngle / 2 + 90))
                                }
                        }
                        Circle()
                            .stroke(glow ? Color.appButter : Color.appChocolate, lineWidth: glow ? 8 : 5)
                        Circle().fill(Color.appCard).frame(width: 54, height: 54).softShadow()
                            .overlay { KitschSparkle().fill(Color.appButter).frame(width: 24, height: 24) }
                    }
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(wheelRotation))
                    // Winner glow pulse once the wheel settles on the landing wedge.
                    .shadow(color: Color.appButter.opacity(winnerPulse ? 0.9 : 0), radius: winnerPulse ? 14 : 0)
                    .scaleEffect(winnerPulse ? 1.02 : 1)
                    .overlay(alignment: .top) {
                        // Fixed pointer at 12 o'clock, outside the rotating stack.
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.appCherry)
                            .offset(y: -12)
                    }
                    .overlay(alignment: .leading) {
                        KitschSparkle().fill(Color.appButter)
                            .frame(width: 28, height: 28).offset(x: -18)
                    }
                    .overlay(alignment: .trailing) {
                        KitschSparkle().fill(Color.appButter)
                            .frame(width: 28, height: 28).offset(x: 18)
                    }
                    .softShadow()

                    PillButton(store.isSpinning ? "돌아가는 중" : "룰렛 돌리기") {
                        guard !store.isSpinning else { return }
                        glow = true
                        store.send(.spin)
                    }
                    .disabled(store.isSpinning)
                    .padding(.horizontal, 48)

                    OutlineButton("게임 나가기") { store.send(.close) }
                }
                .padding(24)
                .task { store.send(.appear) }
            }
        }
        .task(id: store.landingIndex) {
            guard let winner = winnerSliceIndex else { return }
            // Land the winning wedge's mid-angle under the top pointer.
            let target = 360.0 * 4 - (segmentAngle * Double(winner) + segmentAngle / 2)
            withAnimation(.timingCurve(0.15, 0.85, 0.2, 1, duration: spinDuration * 0.88)) {
                wheelRotation = target + segmentAngle * 0.18 // slight overshoot
            }
            try? await Task.sleep(for: .seconds(spinDuration * 0.88))
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 16)) {
                wheelRotation = target // settle exactly
            }
            withAnimation(.easeInOut(duration: 0.32).repeatCount(3, autoreverses: true)) {
                winnerPulse = true
            }
        }
        .task(id: store.result?.id) {
            guard store.result != nil else { return }
            // Let the wheel visibly settle on the winning wedge before the card covers it.
            try? await Task.sleep(for: .seconds(spinDuration + 0.25))
            withAnimation(.spring(response: 0.52, dampingFraction: 0.62)) {
                revealResult = true
                glow = false
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: store.isSpinning)
    }
}

/// A single pie-slice wedge from the wheel center, used to build each roulette segment.
private struct Wedge: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
