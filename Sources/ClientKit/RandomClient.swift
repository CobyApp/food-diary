import Dependencies
import DependenciesMacros
import Models

@DependencyClient
public struct RandomClient: Sendable {
    public var shuffled: @Sendable (_ items: [FoodEntrySnapshot]) -> [FoodEntrySnapshot] = { $0 }
    public var pick: @Sendable (_ items: [FoodEntrySnapshot]) -> FoodEntrySnapshot?
}

extension RandomClient: DependencyKey {
    public static let liveValue = RandomClient(
        shuffled: { $0.shuffled() },
        pick: { $0.randomElement() }
    )
}

extension RandomClient: TestDependencyKey {
    // Deterministic: identity order, pick = first. Games inject their own for
    // exact assertions.
    public static let testValue = RandomClient(shuffled: { $0 }, pick: { $0.first })
    public static let previewValue = testValue
}

public extension DependencyValues {
    var random: RandomClient {
        get { self[RandomClient.self] }
        set { self[RandomClient.self] = newValue }
    }
}
