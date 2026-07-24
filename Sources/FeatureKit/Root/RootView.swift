import SwiftUI
import ComposableArchitecture

public struct RootView: View {
    @Bindable var store: StoreOf<RootFeature>
    public init(store: StoreOf<RootFeature>) { self.store = store }

    public var body: some View {
        TabView(selection: Binding(
            get: { store.tab },
            set: { store.send(.tabChanged($0)) }
        )) {
            NavigationStack(
                path: $store.scope(state: \.path, action: \.path)
            ) {
                CollectionView(store: store.scope(state: \.collection, action: \.collection))
            } destination: { detailStore in
                MealDetailView(store: detailStore)
            }
            .tabItem { Label("컬렉션", systemImage: "square.grid.2x2") }
            .tag(RootFeature.Tab.collection)

            CaptureView(store: store.scope(state: \.capture, action: \.capture))
                .tabItem { Label("담기", systemImage: "plus.circle") }
                .tag(RootFeature.Tab.capture)
        }
    }
}
