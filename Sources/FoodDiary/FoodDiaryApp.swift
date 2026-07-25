import SwiftUI
import SwiftData
import ComposableArchitecture
import FeatureKit
import ClientKit
import Models

@main
struct FoodDiaryApp: App {
    let store: StoreOf<RootFeature>

    init() {
        let container = try! ModelContainer(for: Meal.self, FoodCutout.self)
        let imageStore = ImageStore.disk(directory: ImageStore.cutoutsDirectory)
        store = Store(initialState: RootFeature.State()) {
            RootFeature()
        } withDependencies: {
            $0.persistence = .live(container: container, imageStore: imageStore)
            $0.profileSettings = .live()
            $0.widgetData = .live()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .preferredColorScheme(.light)
        }
    }
}
