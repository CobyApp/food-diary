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

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Array(store.cards.enumerated()), id: \.offset) { index, cutout in
                            Button {
                                lastFlippedIndex = index
                                store.send(.flip(index))
                            } label: {
                                ZStack {
                                    cardBack(index)
                                        .opacity(store.revealedIndices.contains(index) ? 0 : 1)
                                    StickerTile(tint: .rotating(index)) {
                                        CutoutImage(fileName: cutout.fileName)
                                    }
                                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                                    .opacity(store.revealedIndices.contains(index) ? 1 : 0)
                                }
                                .rotation3DEffect(
                                    .degrees(store.revealedIndices.contains(index) ? 180 : 0),
                                    axis: (x: 0, y: 1, z: 0)
                                )
                                .aspectRatio(0.78, contentMode: .fit)
                            }
                            .buttonStyle(KitschPressStyle())
                        }
                    }

                    Text(
                        store.firstRevealedIndex == nil
                            ? L10n.text("같은 누끼 두 장을 찾아봐")
                            : L10n.format("card.moves", store.moves)
                    )
                        .font(.appCaption).foregroundStyle(.appMuted)
                        .contentTransition(.numericText())

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
        .task(id: store.secondRevealedIndex) {
            guard store.secondRevealedIndex != nil, store.result == nil else { return }
            try? await Task.sleep(for: .milliseconds(720))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                _ = store.send(.hideMismatch)
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.72), value: store.revealedIndices)
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
