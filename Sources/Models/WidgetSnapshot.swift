import Foundation

public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public var updatedAt: Date
    public var title: String
    public var subtitle: String
    public var decoration: String?
    public var streak: Int
    public var imageFileName: String?

    public init(
        updatedAt: Date,
        title: String,
        subtitle: String,
        decoration: String?,
        streak: Int,
        imageFileName: String?
    ) {
        self.updatedAt = updatedAt
        self.title = title
        self.subtitle = subtitle
        self.decoration = decoration
        self.streak = streak
        self.imageFileName = imageFileName
    }
}
