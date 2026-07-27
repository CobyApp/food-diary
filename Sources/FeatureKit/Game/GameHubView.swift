import SwiftUI
import ComposableArchitecture

public struct GameHubView: View {
    @Bindable var store: StoreOf<GameHubFeature>
    public init(store: StoreOf<GameHubFeature>) { self.store = store }

    @State private var appeared = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    public var body: some View {
        ScreenScaffold(title: "오늘 뭐먹지") {
            statusStrip

            sectionHeader("혼자 결정", caption: "내 누끼로 바로 정하기")

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(GameKind.allCases.enumerated()), id: \.element) { index, kind in
                    let enabled = store.cutouts.count >= kind.minimum
                    Button { store.send(.gameTapped(kind)) } label: {
                        SoftCard {
                            VStack(alignment: .leading, spacing: 8) {
                                KitschIcon(
                                    kind.symbol,
                                    tint: .appChocolate,
                                    background: [.appPink, .appButter, .appBlue, .appLavender][index],
                                    size: 48
                                )
                                .saturation(enabled ? 1 : 0.35)
                                Text(kind.title)
                                    .font(.appSection).foregroundStyle(.appInk)
                                    .lineLimit(1).minimumScaleFactor(0.85)
                                Text(kind.subtitle)
                                    .font(.appCaption).foregroundStyle(.appMuted)
                                    .lineLimit(2).multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
                        }
                        .overlay(alignment: .topTrailing) {
                            if !enabled {
                                HStack(spacing: 3) {
                                    Image(systemName: "lock.fill")
                                    Text("\(kind.minimum)")
                                }
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appPinkInk)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(Color.appPink.opacity(0.9), in: Capsule())
                                .padding(9)
                            }
                        }
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1 : 1))
                        .opacity(enabled ? 1 : 0.82)
                    }
                    .buttonStyle(KitschPressStyle())
                    .disabled(!enabled)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.85)
                            .delay(Double(index) * 0.06),
                        value: appeared
                    )
                }
            }

            sectionHeader("같이 결정", caption: "친구들과 같은 결과를 함께")

            Button { store.send(.groupTapped) } label: {
                SoftCard {
                    HStack(spacing: 14) {
                        KitschIcon("person.2.fill", tint: .appChocolate, background: .appLavender, size: 50)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.text("함께 정하기"))
                                .font(.appSection).foregroundStyle(.appInk)
                            Text(L10n.text("친구를 초대해 다 같이 결정"))
                                .font(.appCaption).foregroundStyle(.appMuted)
                            Label(L10n.text("게임센터"), systemImage: "gamecontroller.fill")
                                .font(.appCaption).foregroundStyle(.appBlueInk)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.appSection).foregroundStyle(.appMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(KitschPressStyle())
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.85)
                    .delay(0.28),
                value: appeared
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            store.send(.onAppear)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
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

    private var statusStrip: some View {
        let locked = GameKind.allCases.filter { store.cutouts.count < $0.minimum }
        let needed = locked.map(\.minimum).max().map { $0 - store.cutouts.count } ?? 0
        return HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "square.grid.2x2.fill").foregroundStyle(Color.appBlueInk)
                Text(L10n.format("game.myCutouts", store.cutouts.count))
                    .font(.appCaption).foregroundStyle(.appInk)
            }
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Color.appCard, in: Capsule())
            .softShadow()

            if needed > 0 {
                Text(L10n.format("game.needMore", needed))
                    .font(.appCaption).foregroundStyle(.appMuted)
            }
            Spacer()
        }
    }

    private func sectionHeader(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.text(title)).font(.appSection).foregroundStyle(.appInk)
            Text(L10n.text(caption)).font(.appCaption).foregroundStyle(.appMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
