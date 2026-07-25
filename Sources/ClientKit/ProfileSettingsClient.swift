import Dependencies
import DependenciesMacros
import Foundation
import Models

@DependencyClient
public struct ProfileSettingsClient: Sendable {
    public var load: @Sendable () async -> ProfileSnapshot = { ProfileSnapshot() }
    public var save: @Sendable (ProfileSnapshot) async -> Void
}

private actor ProfileSettingsStore {
    private let defaults: UserDefaults
    private let key = "foodieDiary.profile"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func load() -> ProfileSnapshot {
        guard
            let data = defaults.data(forKey: key),
            let profile = try? JSONDecoder().decode(ProfileSnapshot.self, from: data)
        else {
            return ProfileSnapshot()
        }
        return profile
    }

    func save(_ profile: ProfileSnapshot) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }
}

public extension ProfileSettingsClient {
    static func live(defaults: UserDefaults = .standard) -> ProfileSettingsClient {
        let store = ProfileSettingsStore(defaults: defaults)
        return ProfileSettingsClient(
            load: { await store.load() },
            save: { await store.save($0) }
        )
    }
}

extension ProfileSettingsClient: TestDependencyKey {
    public static let testValue = ProfileSettingsClient()
    public static let previewValue = ProfileSettingsClient(
        load: {
            ProfileSnapshot(
                name: "푸디",
                avatar: "ribbon",
                favoriteFood: "라멘",
                hasCompletedOnboarding: true
            )
        },
        save: { _ in }
    )
}

public extension DependencyValues {
    var profileSettings: ProfileSettingsClient {
        get { self[ProfileSettingsClient.self] }
        set { self[ProfileSettingsClient.self] = newValue }
    }
}
