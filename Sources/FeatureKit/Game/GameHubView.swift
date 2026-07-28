import SwiftUI
import ComposableArchitecture
import Models

public struct GameHubView: View {
    @Bindable var store: StoreOf<GameHubFeature>
    public init(store: StoreOf<GameHubFeature>) { self.store = store }

    @State private var appeared = false

    private var soloEnabled: Bool { store.cutouts.count >= GameKind.worldCup.minimum }

    public var body: some View {
        ScreenScaffold(title: "오늘 뭐먹지") {
            sectionHeader("혼자 결정", caption: "내 누끼로 바로 정하기")
            soloCard
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: appeared)

            sectionHeader("같이 결정", caption: "친구들과 같은 결과를 함께")
            groupCard
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.85).delay(0.14),
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

    // MARK: - Solo

    /// Hero card for the solo tournament, previewing two of the player's own
    /// cutouts as the first match-up so the screen shows real content.
    private var soloCard: some View {
        Button { store.send(.gameTapped(.worldCup)) } label: {
            SoftCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        KitschIcon("crown.fill", tint: .appChocolate, background: .appButter, size: 52)
                            .saturation(soloEnabled ? 1 : 0.35)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(GameKind.worldCup.title)
                                .font(.appTitle).foregroundStyle(.appInk)
                            Text(soloEnabled
                                 ? GameKind.worldCup.subtitle
                                 : L10n.format("game.minimum", GameKind.worldCup.minimum))
                                .font(.appCaption)
                                .foregroundStyle(soloEnabled ? .appMuted : .appPinkInk)
                        }
                        Spacer(minLength: 0)
                    }

                    matchPreview

                    HStack(spacing: 6) {
                        Text(L10n.text(soloEnabled ? "토너먼트 시작하기" : "누끼를 더 담아와!"))
                            .font(.appSection)
                            .foregroundStyle(soloEnabled ? .appCherry : .appMuted)
                        if soloEnabled {
                            Image(systemName: "arrow.right")
                                .font(.appCaption).foregroundStyle(.appCherry)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            }
            .overlay(alignment: .topTrailing) {
                if !soloEnabled {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.appPinkInk)
                        .padding(8)
                        .background(Color.appPink.opacity(0.9), in: Circle())
                        .padding(10)
                }
            }
            .opacity(soloEnabled ? 1 : 0.85)
        }
        .buttonStyle(KitschPressStyle())
        .disabled(!soloEnabled)
    }

    /// Two candidate tiles with a VS badge: real cutouts when the player has
    /// them, empty plates as a teaser when the game is still locked.
    private var matchPreview: some View {
        HStack(spacing: 10) {
            previewTile(store.cutouts.first, tint: .pink)
            Text(L10n.text("VS"))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.appCherry)
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(Color.appButter, in: Capsule())
                .softShadow()
            previewTile(store.cutouts.dropFirst().first, tint: .blue)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func previewTile(_ cutout: CutoutSnapshot?, tint: StickerTint) -> some View {
        StickerTile(tint: tint) {
            if let cutout {
                CutoutImage(fileName: cutout.fileName)
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.appMuted.opacity(0.55))
            }
        }
        .frame(height: 132)
    }

    // MARK: - Group

    private var groupCard: some View {
        Button { store.send(.groupTapped) } label: {
            SoftCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        KitschIcon("person.2.fill", tint: .appChocolate, background: .appLavender, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.text("함께 월드컵"))
                                .font(.appTitle).foregroundStyle(.appInk)
                            Text(L10n.text("친구들과 5초 안에 투표해서 정해요"))
                                .font(.appCaption).foregroundStyle(.appMuted)
                        }
                        Spacer(minLength: 0)
                    }

                    // Little rule strip so the mode explains itself.
                    HStack(spacing: 8) {
                        ruleChip("timer", L10n.text("5초 투표"), tone: .appPink)
                        ruleChip("chart.bar.fill", L10n.text("다수결 승리"), tone: .appButter)
                        ruleChip("gamecontroller.fill", L10n.text("게임센터"), tone: .appBlue)
                    }

                    HStack(spacing: 6) {
                        Text(L10n.text("친구 초대하기"))
                            .font(.appSection).foregroundStyle(.appBlueInk)
                        Image(systemName: "arrow.right")
                            .font(.appCaption).foregroundStyle(.appBlueInk)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            }
        }
        .buttonStyle(KitschPressStyle())
    }

    private func ruleChip(_ symbol: String, _ title: String, tone: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(.appInk)
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(tone.opacity(0.55), in: Capsule())
    }

    private func sectionHeader(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.text(title)).font(.appSection).foregroundStyle(.appInk)
            Text(L10n.text(caption)).font(.appCaption).foregroundStyle(.appMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
