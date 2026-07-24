import Foundation
import SwiftData

@Model
public final class FoodCutout {
    public var id: UUID
    public var fileName: String
    public var createdAt: Date
    public var label: String?
    public var meal: Meal?

    public init(
        id: UUID = UUID(),
        fileName: String,
        createdAt: Date = Date(),
        label: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.label = label
    }

    public func snapshot() -> CutoutSnapshot {
        CutoutSnapshot(id: id, fileName: fileName, createdAt: createdAt, label: label)
    }
}
