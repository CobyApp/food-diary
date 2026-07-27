import ComposableArchitecture
import Models
import SwiftUI

public struct CardFlipView: View {
    @Bindable var store: StoreOf<CardFlipFeature>
    @State private var lastFlippedIndex: Int?
    @State private var revealResult = false

    public init(store: StoreOf<CardFlipFeature>) { self.store = store }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    public var body: some View {
        ZStack {
            PaperBackground()
            if let result = store.result, revealResult {
                ResultCard(
                    cutout: result,
                    info: store.resultInfo,
                    onAgain: {
                        lastFlippedIndex = nil
                        revealResult = false
                        store.send(.playAgain)
                    },
                    onClose: { store.send(.close) }
                )
            } else {
                VStack(spacing: 18) {
                    VStack(spacing: 5) {
                        Text("시크릿 카드").font(.appDisplay).foregroundStyle(.appInk)
                        Text("끌리는 패턴 한 장을 골라 뒤집어봐")
                            .font(.appBody).foregroundStyle(.appMuted)
                    }

                    ZStack {
                        if store.result != nil {
                            ConfettiBurst()
                                .frame(width: 260, height: 260)
                            Text("선택 완료!")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .tracking(1)
                                .foregroundStyle(.appCard)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.appCherry, in: Capsule())
                                .softShadow()
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                                .zIndex(1)
                        }
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(Array(store.cards.enumerated()), id: \.offset) { index, cutout in
                                Button {
                                    lastFlippedIndex = index
                                    store.send(.flip(index))
                                } label: {
                                    ZStack {
                                        cardBack(index)
                                            .opacity(store.revealedIndex == index ? 0 : 1)
                                        StickerTile(tint: .rotating(index)) {
                                            CutoutImage(fileName: cutout.fileName)
                                        }
                                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                                        .opacity(store.revealedIndex == index ? 1 : 0)
                                    }
                                    .rotation3DEffect(
                                        .degrees(store.revealedIndex == index ? 180 : 0),
                                        axis: (x: 0, y: 1, z: 0),
                                        perspective: 0.6
                                    )
                                    .aspectRatio(0.78, contentMode: .fit)
                                }
                                .buttonStyle(KitschPressStyle())
                            }
                        }
                    }

                    Text(L10n.text("끌리는 카드 한 장을 골라 뒤집어봐"))
                        .font(.appCaption).foregroundStyle(.appMuted)

                    OutlineButton("게임 나가기") { store.send(.close) }
                }
                .padding(24)
                .task { if store.cards.isEmpty { store.send(.start) } }
            }
        }
        .task(id: store.result?.id) {
            guard store.result != nil else { return }
            try? await Task.sleep(for: .milliseconds(850))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { revealResult = true }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.72), value: store.revealedIndex)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: store.result != nil)
        .sensoryFeedback(.impact(weight: .medium), trigger: lastFlippedIndex)
    }

    private func cardBack(_ index: Int) -> some View {
        RoundedRectangle(cornerRadius: 18)
            .fill([Color.appPink, .appBlue, .appButter, .appLavender][index % 4])
            .overlay {
                VStack(spacing: 7) {
                    KitschSparkle().fill(Color.appCard).frame(width: 26, height: 26)
                    Image(systemName: index.isMultiple(of: 2) ? "heart.fill" : "camera.macro")
                        .font(.title2.bold())
                        .foregroundStyle(Color.appChocolate.opacity(0.7))
                    KitschSparkle().fill(Color.appCard).frame(width: 13, height: 13)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.appCard, style: StrokeStyle(lineWidth: 4, dash: [7, 5]))
                    .padding(5)
            }
            .softShadow()
    }
}
