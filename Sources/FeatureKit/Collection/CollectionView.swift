import SwiftUI
import ComposableArchitecture

public struct CollectionView: View {
    @Bindable var store: StoreOf<CollectionFeature>
    public init(store: StoreOf<CollectionFeature>) { self.store = store }

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.cutouts) { cutout in
                    Button { store.send(.cutoutTapped(cutout.id)) } label: {
                        CutoutImage(fileName: cutout.fileName)
                            .frame(height: 100)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .overlay {
            if store.cutouts.isEmpty && !store.isLoading {
                ContentUnavailableView("아직 누끼가 없어요", systemImage: "fork.knife",
                                       description: Text("음식 사진을 찍어 첫 누끼를 담아보세요!"))
            }
        }
        .navigationTitle("컬렉션")
        .task { store.send(.onAppear) }
    }
}
