import SwiftUI
import ComposableArchitecture

public struct CollectionView: View {
    @Bindable var store: StoreOf<CollectionFeature>
    public init(store: StoreOf<CollectionFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    public var body: some View {
        ScreenScaffold(title: "컬렉션") {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.appCherry)
                    Text(L10n.format("streak.days", store.streak.current))
                        .font(.appSection)
                        .foregroundStyle(.appInk)
                    if store.streak.best > store.streak.current {
                        Text(L10n.format("streak.best", store.streak.best))
                            .font(.appCaption)
                            .foregroundStyle(.appMuted)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.appCard, in: Capsule())
                .softShadow()

                Spacer()

                headerButton(systemImage: "person.crop.circle.fill", color: .appPink) {
                    store.send(.profileButtonTapped)
                }
                headerButton(systemImage: "rectangle.stack.fill", color: .appBlueInk) {
                    store.send(.recapButtonTapped)
                }
                headerButton(systemImage: "rosette", color: .appButterInk) {
                    store.send(.achievementsButtonTapped)
                }
            }

            if store.cutouts.isEmpty {
                if store.isLoading {
                    KitschLoadingView(
                        "누끼 스티커를 꺼내는 중",
                        messages: ["컬렉션을 가지런히 정리하고 있어요"],
                        compact: true
                    )
                } else {
                    EmptyState(systemImage: "fork.knife", title: "아직 누끼가 없어요",
                               subtitle: "음식 사진을 찍어 첫 누끼를 담아보세요!")
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(store.cutouts.enumerated()), id: \.element.id) { index, cutout in
                        Button { store.send(.cutoutTapped(cutout.id)) } label: {
                            StickerTile(tint: .rotating(index)) {
                                CutoutImage(fileName: cutout.fileName)
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if let symbol = CutoutDecoration(label: cutout.label).symbol {
                                    KitschIcon(symbol, tint: .appPinkInk, background: .appPink, size: 34)
                                        .padding(5)
                                }
                            }
                            .rotationEffect(.degrees(index.isMultiple(of: 3) ? -1.2 : index.isMultiple(of: 2) ? 1 : 0))
                        }
                        .buttonStyle(KitschPressStyle())
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            store.send(.onAppear)
            store.send(.streakOnAppear)
            store.send(.profileCheck)
        }
        .sheet(item: $store.scope(state: \.achievements, action: \.achievements)) { achStore in
            AchievementsView(store: achStore)
        }
        .sheet(item: $store.scope(state: \.recap, action: \.recap)) { recapStore in
            RecapView(store: recapStore)
        }
        .sheet(item: $store.scope(state: \.profile, action: \.profile)) { profileStore in
            ProfileView(store: profileStore)
        }
    }

    private func headerButton(
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(Color.appCard, in: Circle())
                .softShadow()
        }
        .buttonStyle(KitschPressStyle())
    }
}
