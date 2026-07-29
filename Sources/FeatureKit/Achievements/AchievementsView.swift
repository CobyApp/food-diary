import SwiftUI
import ComposableArchitecture

public struct AchievementsView: View {
    @Bindable var store: StoreOf<AchievementsFeature>
    public init(store: StoreOf<AchievementsFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    public var body: some View {
        // Same chrome as the other sheets: inline title, 닫기 top-trailing.
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.format(
                        "achievements.progress",
                        store.unlockedCount,
                        store.achievements.count
                    ))
                        .font(.appSection).foregroundStyle(.appBlueInk)

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(store.achievements) { a in badge(a) }
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("음식 도감")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { store.send(.close) }
                }
            }
        }
        .task { store.send(.onAppear) }
    }

    private func badge(_ a: Achievement) -> some View {
        SoftCard {
            VStack(spacing: 8) {
                KitschIcon(
                    a.symbol,
                    tint: a.unlocked ? .appChocolate : .appMuted,
                    background: a.unlocked ? .appButter : .appTileBlue,
                    size: 58
                )
                    .opacity(a.unlocked ? 1 : 0.35)
                    .grayscale(a.unlocked ? 0 : 1)
                Text(a.title).font(.appSection)
                    .foregroundStyle(a.unlocked ? Color.appInk : Color.appMuted)
                if a.unlocked {
                    Text("achievement.collected").font(.appCaption).foregroundStyle(.appPinkInk)
                } else {
                    ProgressView(value: a.progress).tint(.appBlue)
                    Text("\(a.current)/\(a.target)").font(.appCaption).foregroundStyle(.appMuted)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
        }
    }
}
