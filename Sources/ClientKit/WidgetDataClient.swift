import Dependencies
import DependenciesMacros
import Foundation
import Models
import WidgetKit

public enum FoodDiaryShared {
    public static let appGroup = "group.com.coby.food.dairy"
    public static let snapshotKey = "foodieDiary.widgetSnapshot"
    public static let imageFileName = "latest-cutout.png"
}

@DependencyClient
public struct WidgetDataClient: Sendable {
    public var update: @Sendable (_ meal: MealSnapshot, _ streak: Int) async -> Void
    public var clear: @Sendable () async -> Void
}

private actor WidgetDataStore {
    func update(meal: MealSnapshot, streak: Int) {
        guard
            let defaults = UserDefaults(suiteName: FoodDiaryShared.appGroup),
            let directory = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: FoodDiaryShared.appGroup
            )
        else { return }

        let latest = meal.cutouts.first
        var sharedImageName: String?
        if let latest,
           let data = ImageStore.disk(directory: ImageStore.cutoutsDirectory).load(latest.fileName) {
            let url = directory.appendingPathComponent(FoodDiaryShared.imageFileName)
            if (try? data.write(to: url, options: .atomic)) != nil {
                sharedImageName = FoodDiaryShared.imageFileName
            }
        }

        let snapshot = WidgetSnapshot(
            updatedAt: meal.eatenAt,
            title: meal.place?.name ?? NSLocalizedString(
                "오늘의 한 끼", bundle: .main, comment: ""
            ),
            subtitle: meal.memo.isEmpty ? "Foodie Diary" : meal.memo,
            decoration: latest?.label,
            streak: streak,
            imageFileName: sharedImageName
        )
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(encoded, forKey: FoodDiaryShared.snapshotKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "FoodDiaryCutoutWidget")
    }

    func clear() {
        UserDefaults(suiteName: FoodDiaryShared.appGroup)?
            .removeObject(forKey: FoodDiaryShared.snapshotKey)
        if let directory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: FoodDiaryShared.appGroup
        ) {
            try? FileManager.default.removeItem(
                at: directory.appendingPathComponent(FoodDiaryShared.imageFileName)
            )
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "FoodDiaryCutoutWidget")
    }
}

public extension WidgetDataClient {
    static func live() -> WidgetDataClient {
        let store = WidgetDataStore()
        return WidgetDataClient(update: { meal, streak in
            await store.update(meal: meal, streak: streak)
        }, clear: {
            await store.clear()
        })
    }
}

extension WidgetDataClient: TestDependencyKey {
    public static let testValue = WidgetDataClient(update: { _, _ in }, clear: {})
    public static let previewValue = testValue
}

public extension DependencyValues {
    var widgetData: WidgetDataClient {
        get { self[WidgetDataClient.self] }
        set { self[WidgetDataClient.self] = newValue }
    }
}
