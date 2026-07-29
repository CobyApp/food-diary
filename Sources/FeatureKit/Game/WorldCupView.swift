import ComposableArchitecture
import Models
import SwiftUI

public struct WorldCupView: View {
    @Bindable var store: StoreOf<WorldCupFeature>
    @State private var selectedID: UUID?
    @State private var roundBanner: String?
    @State private var vsPop = false

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
                        HStack(spacing: 6) {
                            let matches = max(store.currentRound.count / 2, 1)
                            ForEach(0..<matches, id: \.self) { i in
                                Circle()
                                    .fill(i < store.pairIndex / 2 ? Color.appCherry : Color.appCherry.opacity(0.25))
                                    .frame(width: 7, height: 7)
                            }
                        }
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
                            .scaleEffect(vsPop ? 1.12 : 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: vsPop)
                        contender(pair.1, index: 1)
                    }

                    Text("더 먹고 싶은 쪽을 탭하세요")
                        .font(.appCaption).foregroundStyle(.appMuted)
                    OutlineButton("게임 나가기") { store.send(.close) }
                }
                .padding(20)
            } else {
                KitschLoadingView(
                    "대진표를 섞는 중",
                    messages: ["맛있는 후보들이 입장하고 있어요"]
                )
                .padding(24)
                .task { store.send(.start) }
            }
        }
        .overlay(alignment: .top) {
            if let roundBanner {
                Text(roundBanner)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.appCard)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Color.appCherry, in: Capsule())
                    .softShadow()
                    .padding(.top, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: store.pairIndex)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: roundBanner)
        .sensoryFeedback(.selection, trigger: selectedID)
        .task(id: store.currentRound.count) {
            guard !store.currentRound.isEmpty else { return }
            roundBanner = store.roundName
            try? await Task.sleep(for: .milliseconds(900))
            roundBanner = nil
        }
        .task(id: store.pairIndex) {
            selectedID = nil
            vsPop = true
            try? await Task.sleep(for: .milliseconds(180))
            vsPop = false
        }
    }

    private func contender(_ cutout: FoodEntrySnapshot, index: Int) -> some View {
        let info = store.info[cutout.id]
        return Button {
            selectedID = cutout.id
            store.send(.pick(cutout))
        } label: {
            VStack(spacing: 10) {
                StickerTile(tint: .rotating(index)) {
                    CutoutImage(fileName: cutout.fileName)
                }
                VStack(spacing: 2) {
                    Text(info?.placeName.isEmpty == false ? info!.placeName : L10n.text("이 메뉴"))
                        .font(.appCaption).foregroundStyle(.appChocolate)
                        .lineLimit(1)
                    if let tags = info?.tags, !tags.isEmpty {
                        TagChipRow(tags, limit: 2)
                            .foregroundStyle(.appMuted).lineLimit(1)
                    }
                }
            }
            .padding(8)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.appChocolate.opacity(0.14), lineWidth: 1.5)
            }
            .scaleEffect(selectedID == cutout.id ? 1.1 : (selectedID == nil ? 1 : 0.9))
            .opacity(selectedID == nil || selectedID == cutout.id ? 1 : 0.25)
            .offset(x: selectedID == nil || selectedID == cutout.id ? 0 : (index == 0 ? -40 : 40))
            .rotationEffect(.degrees(index == 0 ? -1.5 : 1.5))
            .softShadow()
            .animation(.spring(response: 0.42, dampingFraction: 0.8), value: selectedID)
        }
        .buttonStyle(KitschPressStyle())
    }
}
