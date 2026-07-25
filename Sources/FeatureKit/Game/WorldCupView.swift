import SwiftUI
import ComposableArchitecture
import Models

public struct WorldCupView: View {
    @Bindable var store: StoreOf<WorldCupFeature>
    public init(store: StoreOf<WorldCupFeature>) { self.store = store }

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            if let champ = store.champion {
                ResultCard(cutout: champ, place: store.championPlace,
                           onAgain: { store.send(.playAgain) },
                           onClose: { store.send(.close) })
            } else if let pair = store.currentPair {
                VStack(spacing: 20) {
                    Text(store.roundName).font(.appDisplay).foregroundStyle(.appBlueInk)
                    contender(pair.0)
                    Text("VS").font(.appTitle).foregroundStyle(.appMuted)
                    contender(pair.1)
                    Button("닫기") { store.send(.close) }.foregroundStyle(.appMuted).padding(.top, 4)
                }
                .padding(24)
            } else {
                ProgressView().tint(.appBlue).task { store.send(.start) }
            }
        }
        .animation(.spring(duration: 0.35), value: store.pairIndex)
    }

    private func contender(_ cutout: CutoutSnapshot) -> some View {
        Button { store.send(.pick(cutout)) } label: {
            StickerTile(tint: .rotating(cutout.id.hashValue)) { CutoutImage(fileName: cutout.fileName) }
                .frame(maxWidth: .infinity).frame(height: 150)
        }
        .buttonStyle(.plain)
    }
}
