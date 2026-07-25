import SwiftUI
import ComposableArchitecture

public struct AchievementsView: View {
    @Bindable var store: StoreOf<AchievementsFeature>
    public init(store: StoreOf<AchievementsFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("음식 도감 🏆").font(.appDisplay).foregroundStyle(.appInk)
                        Spacer()
                        Button { store.send(.close) } label: {
                            Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.appMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("\(store.unlockedCount) / \(store.achievements.count) 달성")
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
                Text(a.emoji)
                    .font(.system(size: 40))
                    .opacity(a.unlocked ? 1 : 0.35)
                    .grayscale(a.unlocked ? 0 : 1)
                Text(a.title).font(.appSection)
                    .foregroundStyle(a.unlocked ? Color.appInk : Color.appMuted)
                if a.unlocked {
                    Text("달성!").font(.appCaption).foregroundStyle(.appPinkInk)
                } else {
                    ProgressView(value: a.progress).tint(.appBlue)
                    Text("\(a.current)/\(a.target)").font(.appCaption).foregroundStyle(.appMuted)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
        }
    }
}
