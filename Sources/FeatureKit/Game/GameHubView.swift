import SwiftUI
import ComposableArchitecture

public struct GameHubView: View {
    @Bindable var store: StoreOf<GameHubFeature>
    public init(store: StoreOf<GameHubFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    public var body: some View {
        ScreenScaffold(title: "오늘 뭐먹지 🎲") {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(GameKind.allCases, id: \.self) { kind in
                    let enabled = store.cutouts.count >= kind.minimum
                    Button { store.send(.gameTapped(kind)) } label: {
                        SoftCard {
                            VStack(spacing: 8) {
                                Text(kind.emoji).font(.system(size: 44))
                                Text(kind.title).font(.appSection).foregroundStyle(.appInk)
                                if !enabled {
                                    Text("누끼를 더 담아와!").font(.appCaption).foregroundStyle(.appMuted)
                                }
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                        }
                        .opacity(enabled ? 1 : 0.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { store.send(.onAppear) }
        .fullScreenCover(item: $store.scope(state: \.game, action: \.game)) { gameStore in
            switch gameStore.case {
            case let .gacha(s): GachaView(store: s)
            case let .worldCup(s): WorldCupView(store: s)
            case let .cardFlip(s): CardFlipView(store: s)
            case let .roulette(s): RouletteView(store: s)
            }
        }
    }
}
