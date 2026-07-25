import SwiftUI
import ComposableArchitecture

public struct RootView: View {
    @Bindable var store: StoreOf<RootFeature>
    public init(store: StoreOf<RootFeature>) { self.store = store }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.appMilk.ignoresSafeArea()

            switch store.tab {
            case .collection:
                NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
                    CollectionView(store: store.scope(state: \.collection, action: \.collection))
                } destination: { detailStore in
                    MealDetailView(store: detailStore)
                }
            case .capture:
                CaptureView(store: store.scope(state: \.capture, action: \.capture))
            case .game:
                GameHubView(store: store.scope(state: \.gameHub, action: \.gameHub))
            case .map:
                FoodMapView(store: store.scope(state: \.foodMap, action: \.foodMap))
            }

            FloatingTabBar(selected: store.tab) { store.send(.tabChanged($0)) }
        }
    }
}
