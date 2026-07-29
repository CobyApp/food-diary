import Foundation
import SwiftData
import Dependencies
import DependenciesMacros
import Models

/// One food about to be saved, with the information that belongs to it alone.
public struct NewEntry: Sendable {
    public var pngData: Data
    public var label: String?
    public var tags: [String]
    public var rating: Int?

    public init(pngData: Data, label: String? = nil, tags: [String] = [], rating: Int? = nil) {
        self.pngData = pngData
        self.label = label
        self.tags = tags
        self.rating = rating
    }
}

@DependencyClient
public struct PersistenceClient: Sendable {
    /// Saves one record per food. `place` and the time are shared by the batch —
    /// they describe the sitting — while tags and rating come from each entry.
    public var saveEntries: @Sendable (
        _ place: PlaceInfo?, _ entries: [NewEntry]
    ) async throws -> [FoodEntrySnapshot]
    /// Newest first.
    public var allEntries: @Sendable () async throws -> [FoodEntrySnapshot]
    public var entry: @Sendable (_ id: UUID) async throws -> FoodEntrySnapshot?
    public var deleteEntries: @Sendable (_ ids: Set<UUID>) async throws -> Void
    /// The tag catalog, alphabetical.
    public var allTags: @Sendable () async throws -> [String]
    /// Adds a tag to the catalog; a tag that already exists is left alone.
    public var createTag: @Sendable (_ name: String) async throws -> Void
    /// Renames the catalog entry and rewrites the name on every food using it.
    public var renameTag: @Sendable (_ from: String, _ to: String) async throws -> Void
    /// Removes the catalog entry and strips it from every food.
    public var deleteTag: @Sendable (_ name: String) async throws -> Void
}

@ModelActor
actor PersistenceActor {
    // ImageStore (Sendable) is passed per call rather than stored, so live()
    // needs no async setter and there is no window where it is unset.
    func save(
        place: PlaceInfo?,
        entries: [NewEntry],
        imageStore: ImageStore
    ) throws -> [FoodEntrySnapshot] {
        var written: [String] = []
        var inserted: [FoodEntry] = []
        do {
            // One shared timestamp: these were eaten at the same sitting.
            let eatenAt = Date()
            for new in entries {
                let name = try imageStore.save(new.pngData)
                written.append(name)
                let entry = FoodEntry(
                    fileName: name,
                    eatenAt: eatenAt,
                    label: new.label,
                    tags: TagName.cleaned(new.tags),
                    rating: new.rating
                )
                entry.place = place
                modelContext.insert(entry)
                inserted.append(entry)
            }
            try modelContext.save()
        } catch {
            // Track what we wrote so a later failure doesn't leave orphaned PNGs.
            for name in written { try? imageStore.delete(name) }
            modelContext.rollback()
            throw error
        }
        return inserted.map { $0.snapshot() }
    }

    func allEntries() throws -> [FoodEntrySnapshot] {
        let descriptor = FetchDescriptor<FoodEntry>(
            sortBy: [SortDescriptor(\.eatenAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.snapshot() }
    }

    func entry(id: UUID) throws -> FoodEntrySnapshot? {
        let descriptor = FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.snapshot()
    }

    func deleteEntries(ids: Set<UUID>, imageStore: ImageStore) throws {
        let all = try modelContext.fetch(FetchDescriptor<FoodEntry>())
        for entry in all where ids.contains(entry.id) {
            try? imageStore.delete(entry.fileName)
            modelContext.delete(entry)
        }
        try modelContext.save()
    }

    func allTags() throws -> [String] {
        let descriptor = FetchDescriptor<FoodTag>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(\.name)
    }

    func createTag(name: String) throws {
        guard let name = TagName.normalize(name) else { return }
        let existing = try modelContext.fetch(FetchDescriptor<FoodTag>()).map(\.name)
        guard !existing.contains(where: { TagName.isSame($0, name) }) else { return }
        modelContext.insert(FoodTag(name: name))
        try modelContext.save()
    }

    func renameTag(from old: String, to new: String) throws {
        guard let new = TagName.normalize(new) else { return }
        let tags = try modelContext.fetch(FetchDescriptor<FoodTag>())
        guard let tag = tags.first(where: { TagName.isSame($0.name, old) }) else { return }
        // A rename onto a name that already exists would collapse two tags into
        // one; merge instead of writing a duplicate.
        if let clash = tags.first(where: { TagName.isSame($0.name, new) }), clash !== tag {
            modelContext.delete(tag)
        } else {
            tag.name = new
        }
        // Foods hold names, so every one carrying the old name has to be rewritten.
        for entry in try modelContext.fetch(FetchDescriptor<FoodEntry>()) {
            guard entry.tags.contains(where: { TagName.isSame($0, old) }) else { continue }
            entry.tags = TagName.cleaned(
                entry.tags.map { TagName.isSame($0, old) ? new : $0 }
            )
        }
        try modelContext.save()
    }

    func deleteTag(name: String) throws {
        for tag in try modelContext.fetch(FetchDescriptor<FoodTag>())
        where TagName.isSame(tag.name, name) {
            modelContext.delete(tag)
        }
        for entry in try modelContext.fetch(FetchDescriptor<FoodEntry>()) {
            let kept = entry.tags.filter { !TagName.isSame($0, name) }
            if kept.count != entry.tags.count { entry.tags = kept }
        }
        try modelContext.save()
    }
}

public extension PersistenceClient {
    static func live(container: ModelContainer, imageStore: ImageStore) -> PersistenceClient {
        let actor = PersistenceActor(modelContainer: container)
        return PersistenceClient(
            saveEntries: { place, entries in
                try await actor.save(place: place, entries: entries, imageStore: imageStore)
            },
            allEntries: { try await actor.allEntries() },
            entry: { id in try await actor.entry(id: id) },
            deleteEntries: { ids in
                try await actor.deleteEntries(ids: ids, imageStore: imageStore)
            },
            allTags: { try await actor.allTags() },
            createTag: { name in try await actor.createTag(name: name) },
            renameTag: { from, to in try await actor.renameTag(from: from, to: to) },
            deleteTag: { name in try await actor.deleteTag(name: name) }
        )
    }
}

extension PersistenceClient: TestDependencyKey {
    public static let testValue = PersistenceClient()
    public static let previewValue = PersistenceClient(
        saveEntries: { place, entries in
            entries.enumerated().map { offset, entry in
                FoodEntrySnapshot(
                    id: UUID(),
                    fileName: "\(offset).png",
                    eatenAt: Date(),
                    label: entry.label,
                    place: place,
                    tags: entry.tags,
                    rating: entry.rating
                )
            }
        },
        allEntries: { [] },
        entry: { _ in nil },
        deleteEntries: { _ in },
        allTags: { ["라멘", "카페"] },
        createTag: { _ in },
        renameTag: { _, _ in },
        deleteTag: { _ in }
    )
}

public extension DependencyValues {
    var persistence: PersistenceClient {
        get { self[PersistenceClient.self] }
        set { self[PersistenceClient.self] = newValue }
    }
}
