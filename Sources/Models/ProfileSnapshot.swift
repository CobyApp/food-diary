import Foundation

public struct ProfileSnapshot: Codable, Equatable, Sendable {
    public var name: String
    public var avatar: String
    public var favoriteFood: String
    public var hasCompletedOnboarding: Bool

    public init(
        name: String = "",
        avatar: String = "heart",
        favoriteFood: String = "",
        hasCompletedOnboarding: Bool = false
    ) {
        self.name = name
        self.avatar = avatar
        self.favoriteFood = favoriteFood
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}
