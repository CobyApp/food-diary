import SwiftUI
import ComposableArchitecture

public struct AchievementsView: View {
    @Bindable var store: StoreOf<AchievementsFeature>
    public init(store: StoreOf<AchievementsFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    public var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("음식 도감").font(.appDisplay).foregroundStyle(.appInk)
                        Spacer()
                        Button { store.send(.close) } label: {
                            Image(systemName: "xmark")
                                .font(.caption.bold())
                                .foregroundStyle(.appInk)
                                .frame(width: 34, height: 34)
                                .background(Color.appCard, in: Circle())
                                .overlay {
                                    Circle().stroke(
                                        Color.appChocolate.opacity(0.25),
                                        lineWidth: 1.5
                                    )
                                }
                        }
                        .buttonStyle(KitschPressStyle())
                    }
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
