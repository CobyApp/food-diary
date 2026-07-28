import SwiftUI
import ComposableArchitecture

public struct GameHubView: View {
    @Bindable var store: StoreOf<GameHubFeature>
    public init(store: StoreOf<GameHubFeature>) { self.store = store }

    @State private var appeared = false

    public var body: some View {
        ScreenScaffold(title: "오늘 뭐먹지") {
            statusStrip

            sectionHeader("혼자 결정", caption: "내 누끼로 바로 정하기")

            let soloEnabled = store.cutouts.count >= GameKind.worldCup.minimum
            Button { store.send(.gameTapped(.worldCup)) } label: {
                SoftCard {
                    HStack(spacing: 14) {
                        KitschIcon("crown.fill", tint: .appChocolate, background: .appButter, size: 50)
                            .saturation(soloEnabled ? 1 : 0.35)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(GameKind.worldCup.title)
                                .font(.appSection).foregroundStyle(.appInk)
                            Text(GameKind.worldCup.subtitle)
                                .font(.appCaption).foregroundStyle(.appMuted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.appSection).foregroundStyle(.appMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .overlay(alignment: .topTrailing) {
                    if !soloEnabled {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                            Text("\(GameKind.worldCup.minimum)")
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appPinkInk)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color.appPink.opacity(0.9), in: Capsule())
                        .padding(9)
                    }
                }
                .opacity(soloEnabled ? 1 : 0.82)
            }
            .buttonStyle(KitschPressStyle())
            .disabled(!soloEnabled)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.85),
                value: appeared
            )

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
            case let .worldCup(s): WorldCupView(store: s)
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
