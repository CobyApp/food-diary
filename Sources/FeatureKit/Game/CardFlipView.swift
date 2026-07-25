import SwiftUI
import ComposableArchitecture
import Models

public struct CardFlipView: View {
    @Bindable var store: StoreOf<CardFlipFeature>
    public init(store: StoreOf<CardFlipFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 12)]

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            if let result = store.result {
                ResultCard(cutout: result, place: store.resultPlace,
                           onAgain: { store.send(.playAgain) },
                           onClose: { store.send(.close) })
            } else {
                VStack(spacing: 18) {
                    Text("카드 뒤집기 🃏").font(.appDisplay).foregroundStyle(.appInk)
                    Text("카드 하나를 골라 뒤집어요").font(.appBody).foregroundStyle(.appMuted)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(store.cards.enumerated()), id: \.offset) { index, _ in
                            Button { store.send(.flip(index)) } label: {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(Color.appTileBlue)
                                    .overlay(Text("?").font(.appDisplay).foregroundStyle(.appBlue))
                                    .aspectRatio(1, contentMode: .fit)
                                    .softShadow()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button("닫기") { store.send(.close) }.foregroundStyle(.appMuted)
                }
                .padding(24)
                .task { if store.cards.isEmpty { store.send(.start) } }
            }
        }
        .animation(.spring(duration: 0.4), value: store.revealedIndex)
    }
}
