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

            sectionHeader("혼자 결정", caption: "내 누끼로 바로 정하기")

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

            sectionHeader("같이 결정", caption: "친구들과 같은 결과를 함께")

            Button { store.send(.groupTapped) } label: {
                SoftCard {
                    VStack(alignment: .leading, spacing: 10) {
                        KitschIcon("person.2.fill", tint: .appChocolate, background: .appLavender, size: 56)
                        Text(L10n.text("함께 정하기")).font(.appTitle).foregroundStyle(.appInk)
                        Text(L10n.text("친구를 초대해 다 같이 결정"))
                            .font(.appCaption).foregroundStyle(.appMuted)
                            .multilineTextAlignment(.leading)
                        Label(L10n.text("게임센터"), systemImage: "gamecontroller.fill")
                            .font(.appCaption).foregroundStyle(.appBlueInk)
                    }
                    .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
                }
                .rotationEffect(.degrees(1))
            }
            .buttonStyle(KitschPressStyle())
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
        .fullScreenCover(item: $store.scope(state: \.groupDecider, action: \.groupDecider)) { groupStore in
            GroupDeciderView(store: groupStore)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: store.game != nil)
    }

    private func sectionHeader(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.text(title)).font(.appSection).foregroundStyle(.appInk)
            Text(L10n.text(caption)).font(.appCaption).foregroundStyle(.appMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
