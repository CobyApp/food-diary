import ComposableArchitecture
import Models
import SwiftUI

public struct RouletteView: View {
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
                    place: store.resultPlace,
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
                                .frame(width: 142, height: 112)
                                .padding(.vertical, 4)
                            }
                        }
                        .offset(y: reelOffset)
                    }
                    .frame(width: 250, height: 270)
                    .clipped()
                    .overlay {
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(glow ? Color.appButter : Color.appChocolate, lineWidth: glow ? 8 : 3)
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
                        withAnimation(.timingCurve(0.12, 0.8, 0.2, 1, duration: 1.45)) {
                            reelOffset = -CGFloat(max(store.reel.count - 2, 1)) * 120
                        }
                        store.send(.spin)
                    }
                    .disabled(store.isSpinning)
                    .padding(.horizontal, 48)

                    Button("게임 나가기") { store.send(.close) }
                        .font(.appCaption).foregroundStyle(.appMuted)
                }
                .padding(24)
                .task { store.send(.appear) }
            }
        }
        .task(id: store.result?.id) {
            guard store.result != nil else { return }
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.spring(response: 0.52, dampingFraction: 0.62)) {
                revealResult = true
                glow = false
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: store.isSpinning)
    }
}
