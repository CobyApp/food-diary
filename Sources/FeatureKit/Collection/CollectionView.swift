import SwiftUI
import ComposableArchitecture

public struct CollectionView: View {
    @Bindable var store: StoreOf<CollectionFeature>
    public init(store: StoreOf<CollectionFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    public var body: some View {
        ScreenScaffold(title: "컬렉션") {
            if store.cutouts.isEmpty {
                if !store.isLoading {
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
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { store.send(.onAppear) }
        .overlay(alignment: .topTrailing) {
            Button { store.send(.achievementsButtonTapped) } label: {
                Text("🏆").font(.title2)
                    .padding(10).background(Color.appCard, in: Circle()).softShadow()
            }
            .buttonStyle(.plain)
            .padding(.trailing, 18).padding(.top, 6)
        }
        .sheet(item: $store.scope(state: \.achievements, action: \.achievements)) { achStore in
            AchievementsView(store: achStore)
        }
    }
}
