import SwiftUI
import ComposableArchitecture

public struct GameHubView: View {
    @Bindable var store: StoreOf<GameHubFeature>
    public init(store: StoreOf<GameHubFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 14)]

    public var body: some View {
        ScreenScaffold(title: "오늘 뭐먹지") {
            SoftCard {
                HStack(spacing: 14) {
                    KitschIcon("wand.and.stars", tint: .appChocolate, background: .appButter, size: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("결정은 게임에게 맡겨")
                            .font(.appSection).foregroundStyle(.appInk)
                        Text("모아둔 누끼가 많을수록 더 재밌어져요.")
                            .font(.appCaption).foregroundStyle(.appMuted)
                    }
                }
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(GameKind.allCases.enumerated()), id: \.element) { index, kind in
                    let enabled = store.cutouts.count >= kind.minimum
                    Button { store.send(.gameTapped(kind)) } label: {
                        SoftCard {
                            VStack(alignment: .leading, spacing: 10) {
                                KitschIcon(
                                    kind.symbol,
                                    tint: .appChocolate,
                                    background: [.appPink, .appButter, .appBlue, .appLavender][index],
                                    size: 56
                                )
                                Text(kind.title).font(.appTitle).foregroundStyle(.appInk)
                                Text(kind.subtitle)
                                    .font(.appCaption).foregroundStyle(.appMuted)
                                    .multilineTextAlignment(.leading)
                                if !enabled {
                                    Label(
                                        L10n.format("game.minimum", kind.minimum),
                                        systemImage: "lock.fill"
                                    )
                                        .font(.appCaption).foregroundStyle(.appPinkInk)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
                        }
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1 : 1))
                        .opacity(enabled ? 1 : 0.5)
                    }
                    .buttonStyle(KitschPressStyle())
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
        .sensoryFeedback(.impact(weight: .medium), trigger: store.game != nil)
    }
}
