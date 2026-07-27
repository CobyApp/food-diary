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
    public var allMeals: @Sendable () async throws -> [MealSnapshot]
    public var meal: @Sendable (_ id: UUID) async throws -> MealSnapshot?
    public var mealByCutout: @Sendable (_ cutoutID: UUID) async throws -> MealSnapshot?
    public var deleteCutouts: @Sendable (_ ids: Set<UUID>) async throws -> Void
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
        // Track what we wrote so a later failure doesn't leave orphaned PNGs.
        var written: [String] = []
        do {
            for new in cutouts {
                let name = try imageStore.save(new.pngData)
                written.append(name)
                let cutout = FoodCutout(fileName: name, label: new.label)
                cutout.meal = meal
                meal.cutouts.append(cutout)
            }
            modelContext.insert(meal)
            try modelContext.save()
        } catch {
            for name in written { try? imageStore.delete(name) }
            modelContext.rollback()
            throw error
        }
        return meal.snapshot()
    }

    func allCutouts() throws -> [CutoutSnapshot] {
        let descriptor = FetchDescriptor<FoodCutout>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.snapshot() }
    }

    func allMeals() throws -> [MealSnapshot] {
        let descriptor = FetchDescriptor<Meal>(
            sortBy: [SortDescriptor(\.eatenAt, order: .reverse)]
        )
        let meals = try modelContext.fetch(descriptor)
        let emptyMeals = meals.filter(\.cutouts.isEmpty)
        let snapshots = meals.filter { !$0.cutouts.isEmpty }.map { $0.snapshot() }
        if !emptyMeals.isEmpty {
            emptyMeals.forEach(modelContext.delete)
            try modelContext.save()
        }
        return snapshots
    }

    func meal(id: UUID) throws -> MealSnapshot? {
        let descriptor = FetchDescriptor<Meal>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.snapshot()
    }

    func mealByCutout(id: UUID) throws -> MealSnapshot? {
        let descriptor = FetchDescriptor<FoodCutout>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.meal?.snapshot()
    }

    func deleteCutouts(ids: Set<UUID>, imageStore: ImageStore) throws {
        guard !ids.isEmpty else { return }
        let cutouts = try modelContext.fetch(FetchDescriptor<FoodCutout>())
            .filter { ids.contains($0.id) }
        let mealsToDelete = Dictionary(
            cutouts.compactMap(\.meal)
                .filter { meal in
                    !meal.cutouts.isEmpty && meal.cutouts.allSatisfy { ids.contains($0.id) }
                }
                .map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for cutout in cutouts {
            try? imageStore.delete(cutout.fileName)
            if let mealID = cutout.meal?.id, mealsToDelete[mealID] != nil {
                continue
            }
            modelContext.delete(cutout)
        }
        mealsToDelete.values.forEach(modelContext.delete)
        try modelContext.save()
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
            allMeals: { try await actor.allMeals() },
            meal: { id in try await actor.meal(id: id) },
            mealByCutout: { id in try await actor.mealByCutout(id: id) },
            deleteCutouts: { ids in
                try await actor.deleteCutouts(ids: ids, imageStore: imageStore)
            },
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
        allMeals: { [] },
        meal: { _ in nil },
        mealByCutout: { _ in nil },
        deleteCutouts: { _ in },
        deleteMeal: { _ in }
    )
}

public extension DependencyValues {
    var persistence: PersistenceClient {
        get { self[PersistenceClient.self] }
        set { self[PersistenceClient.self] = newValue }
    }
}
