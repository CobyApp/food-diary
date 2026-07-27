import ComposableArchitecture
import Models
import SwiftUI

public struct RouletteView: View {
    // Reel slot geometry: row height (112) + vertical padding (4 top + 4 bottom) = 120.
    // These must match the `.frame`/`.padding` values on each reel row below.
    private let slotHeight: CGFloat = 120
    private let windowHeight: CGFloat = 270
    /// Shared by the reel animation and the reveal delay so they can never drift apart.
    private let spinDuration: TimeInterval = 1.6

    @Bindable var store: StoreOf<RouletteFeature>
    @State private var revealResult = false
    @State private var reelOffset: CGFloat = 0
    @State private var glow = false

    public init(store: StoreOf<RouletteFeature>) { self.store = store }

    public var body: some View {
        ZStack {
            PaperBackground()
            if let result = store.result, revealResult {
                ResultCard(
                    cutout: result,
                    info: store.resultInfo,
                    onAgain: {
                        revealResult = false
                        reelOffset = 0
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
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.appCherry)
                            .overlay {
                                RoundedRectangle(cornerRadius: 30)
                                    .stroke(Color.appCard, lineWidth: 5)
                                    .padding(4)
                            }
                        VStack(spacing: 0) {
                            ForEach(Array(store.reel.enumerated()), id: \.offset) { index, cutout in
                                StickerTile(tint: .rotating(index)) {
                                    CutoutImage(fileName: cutout.fileName)
                                }
                                .frame(width: 142, height: slotHeight - 8)
                                .padding(.vertical, 4)
                            }
                        }
                        .offset(y: reelOffset)
                    }
                    .frame(width: 250, height: windowHeight)
                    .clipped()
                    .overlay {
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(glow ? Color.appButter : Color.appChocolate, lineWidth: glow ? 8 : 3)
                    }
                    .overlay(alignment: .center) {
                        // Center pointer marking the slot the reel will land on.
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appCherry, lineWidth: 4)
                            .frame(height: slotHeight)
                            .overlay(alignment: .leading) {
                                Image(systemName: "arrowtriangle.right.fill")
                                    .foregroundStyle(Color.appCherry).offset(x: -14)
                            }
                            .overlay(alignment: .trailing) {
                                Image(systemName: "arrowtriangle.left.fill")
                                    .foregroundStyle(Color.appCherry).offset(x: 14)
                            }
                            .allowsHitTesting(false)
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
            guard let index = store.landingIndex else { return }
            withAnimation(.timingCurve(0.12, 0.8, 0.2, 1, duration: spinDuration)) {
                // Center the winning slot in the reel window.
                reelOffset = -CGFloat(index) * slotHeight + (windowHeight - slotHeight) / 2
            }
        }
        .task(id: store.result?.id) {
            guard store.result != nil else { return }
            // Let the reel visibly settle on the winning slot before the card covers it.
            try? await Task.sleep(for: .seconds(spinDuration + 0.25))
            withAnimation(.spring(response: 0.52, dampingFraction: 0.62)) {
                revealResult = true
                glow = false
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: store.isSpinning)
    }
}
