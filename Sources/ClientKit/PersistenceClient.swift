import Foundation
import SwiftData
import Dependencies
import DependenciesMacros
import Models

public struct NewCutout: Sendable {
    public var pngData: Data
    public var label: String?
    public init(pngData: Data, label: String? = nil) {
        self.pngData = pngData
        self.label = label
    }
}

@DependencyClient
public struct PersistenceClient: Sendable {
    public var saveMeal: @Sendable (
        _ place: PlaceInfo?, _ memo: String, _ rating: Int?, _ cutouts: [NewCutout]
    ) async throws -> MealSnapshot
    public var allCutouts: @Sendable () async throws -> [CutoutSnapshot]
    public var meal: @Sendable (_ id: UUID) async throws -> MealSnapshot?
    public var deleteMeal: @Sendable (_ id: UUID) async throws -> Void
}

@ModelActor
actor PersistenceActor {
    // ImageStore (Sendable) is passed per call rather than stored, so live()
    // needs no async setter and there is no window where it is unset.
    func save(
        place: PlaceInfo?, memo: String, rating: Int?, cutouts: [NewCutout],
        imageStore: ImageStore
    ) throws -> MealSnapshot {
        let meal = Meal(memo: memo, rating: rating)
        meal.place = place
        for new in cutouts {
            let name = try imageStore.save(new.pngData)
            let cutout = FoodCutout(fileName: name, label: new.label)
            cutout.meal = meal
            meal.cutouts.append(cutout)
        }
        modelContext.insert(meal)
        try modelContext.save()
        return meal.snapshot()
    }

    func allCutouts() throws -> [CutoutSnapshot] {
        let descriptor = FetchDescriptor<FoodCutout>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.snapshot() }
    }

    func meal(id: UUID) throws -> MealSnapshot? {
        let descriptor = FetchDescriptor<Meal>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.snapshot()
    }

    func delete(id: UUID, imageStore: ImageStore) throws {
        let descriptor = FetchDescriptor<Meal>(predicate: #Predicate { $0.id == id })
        guard let meal = try modelContext.fetch(descriptor).first else { return }
        for cutout in meal.cutouts { try? imageStore.delete(cutout.fileName) }
        modelContext.delete(meal)
        try modelContext.save()
    }
}

public extension PersistenceClient {
    static func live(container: ModelContainer, imageStore: ImageStore) -> PersistenceClient {
        let actor = PersistenceActor(modelContainer: container)
        return PersistenceClient(
            saveMeal: { place, memo, rating, cutouts in
                try await actor.save(
                    place: place, memo: memo, rating: rating, cutouts: cutouts,
                    imageStore: imageStore
                )
            },
            allCutouts: { try await actor.allCutouts() },
            meal: { id in try await actor.meal(id: id) },
            deleteMeal: { id in try await actor.delete(id: id, imageStore: imageStore) }
        )
    }
}

extension PersistenceClient: TestDependencyKey {
    public static let testValue = PersistenceClient()
    public static let previewValue = PersistenceClient(
        saveMeal: { place, memo, rating, cutouts in
            MealSnapshot(id: UUID(), eatenAt: Date(), place: place, memo: memo, rating: rating,
                         cutouts: cutouts.enumerated().map {
                             CutoutSnapshot(id: UUID(), fileName: "\($0.offset).png",
                                            createdAt: Date(), label: $0.element.label)
                         })
        },
        allCutouts: { [] },
        meal: { _ in nil },
        deleteMeal: { _ in }
    )
}

public extension DependencyValues {
    var persistence: PersistenceClient {
        get { self[PersistenceClient.self] }
        set { self[PersistenceClient.self] = newValue }
    }
}
