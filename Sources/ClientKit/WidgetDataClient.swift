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
    public var update: @Sendable (_ entry: FoodEntrySnapshot, _ streak: Int) async -> Void
    public var clear: @Sendable () async -> Void
}

private actor WidgetDataStore {
    func update(entry: FoodEntrySnapshot, streak: Int) {
        guard
            let defaults = UserDefaults(suiteName: FoodDiaryShared.appGroup),
            let directory = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: FoodDiaryShared.appGroup
            )
        else { return }

        var sharedImageName: String?
        if let data = ImageStore.disk(directory: ImageStore.cutoutsDirectory)
            .load(entry.fileName) {
            let url = directory.appendingPathComponent(FoodDiaryShared.imageFileName)
            if (try? data.write(to: url, options: .atomic)) != nil {
                sharedImageName = FoodDiaryShared.imageFileName
            }
        }

        let snapshot = WidgetSnapshot(
            updatedAt: entry.eatenAt,
            title: entry.place?.name ?? NSLocalizedString(
                "오늘의 한 끼", bundle: .main, comment: ""
            ),
            subtitle: entry.tags.isEmpty ? "Yumkie" : entry.tags.joined(separator: " · "),
            decoration: entry.label,
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
        return WidgetDataClient(update: { entry, streak in
            await store.update(entry: entry, streak: streak)
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
