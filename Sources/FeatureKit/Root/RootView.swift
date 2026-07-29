import SwiftUI
import ComposableArchitecture

public struct RootView: View {
    @Bindable var store: StoreOf<RootFeature>
    public init(store: StoreOf<RootFeature>) { self.store = store }

    public var body: some View {
        ZStack(alignment: .bottom) {
            PaperBackground()

            Group {
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
            }

            // Capturing takes the whole screen once it is under way: the tab bar
            // sat on top of each step's action button, and there is nowhere else
            // to be until the meal is saved or abandoned.
            if !isCapturing {
                FloatingTabBar(selected: store.tab) { store.send(.tabChanged($0)) }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isCapturing)
        .sensoryFeedback(.selection, trigger: store.tab)
    }

    private var isCapturing: Bool {
        store.tab == .capture && store.capture.step != .source
    }
}
