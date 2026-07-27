import ComposableArchitecture
import Models
import SwiftUI

public struct WorldCupView: View {
    @Bindable var store: StoreOf<WorldCupFeature>
    @State private var selectedID: UUID?

    public init(store: StoreOf<WorldCupFeature>) { self.store = store }

    public var body: some View {
        ZStack {
            PaperBackground()
            if let champion = store.champion {
                ResultCard(
                    cutout: champion,
                    info: store.championInfo,
                    onAgain: {
                        selectedID = nil
                        store.send(.playAgain)
                    },
                    onClose: { store.send(.close) }
                )
            } else if let pair = store.currentPair {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Text("FOOD TASTE MATCH")
                            .font(.appCaption).tracking(1.6).foregroundStyle(.appPinkInk)
                        Text(store.roundName).font(.appDisplay).foregroundStyle(.appInk)
                        ProgressView(
                            value: Double(store.pairIndex + 2),
                            total: Double(max(store.currentRound.count, 2))
                        )
                        .tint(.appCherry)
                        .frame(maxWidth: 220)
                    }

                    HStack(spacing: 10) {
                        contender(pair.0, index: 0)
                        Text("VS")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.appCard)
                            .frame(width: 46, height: 46)
                            .background(Color.appCherry, in: Circle())
                            .overlay { Circle().stroke(Color.appCard, lineWidth: 3) }
                            .zIndex(2)
                        contender(pair.1, index: 1)
                    }

                    Text("더 먹고 싶은 쪽을 탭하세요")
                        .font(.appCaption).foregroundStyle(.appMuted)
                    OutlineButton("게임 나가기") { store.send(.close) }
                }
                .padding(20)
                .id(store.pairIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                KitschLoadingView(
                    "대진표를 섞는 중",
                    messages: ["맛있는 후보들이 입장하고 있어요"]
                )
                .padding(24)
                .task { store.send(.start) }
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: store.pairIndex)
        .sensoryFeedback(.selection, trigger: selectedID)
    }

    private func contender(_ cutout: CutoutSnapshot, index: Int) -> some View {
        Button {
            selectedID = cutout.id
            store.send(.pick(cutout))
        } label: {
            VStack(spacing: 10) {
                StickerTile(tint: .rotating(index)) {
                    CutoutImage(fileName: cutout.fileName)
                }
                Text(index == 0 ? "LEFT PICK" : "RIGHT PICK")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.appChocolate)
            }
            .padding(8)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.appChocolate.opacity(0.14), lineWidth: 1.5)
            }
            .scaleEffect(selectedID == cutout.id ? 1.06 : 1)
            .rotationEffect(.degrees(index == 0 ? -1.5 : 1.5))
            .softShadow()
        }
        .buttonStyle(KitschPressStyle())
    }
}
