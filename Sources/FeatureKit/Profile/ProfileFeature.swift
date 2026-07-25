import ClientKit
import ComposableArchitecture
import Foundation
import Models

@Reducer
public struct ProfileFeature {
    @ObservableState
    public struct State: Equatable {
        public var name: String
        public var avatar: String
        public var favoriteFood: String
        public var isOnboarding: Bool
        public var isSaving = false

        public init(profile: ProfileSnapshot = ProfileSnapshot(), isOnboarding: Bool = false) {
            self.name = profile.name
            self.avatar = profile.avatar
            self.favoriteFood = profile.favoriteFood
            self.isOnboarding = isOnboarding
        }

        public var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public enum Action: Equatable {
        case nameChanged(String)
        case avatarSelected(String)
        case favoriteFoodChanged(String)
        case saveTapped
        case saved(ProfileSnapshot)
        case close
    }

    @Dependency(\.profileSettings) var profileSettings

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .nameChanged(value):
                state.name = value
                return .none
            case let .avatarSelected(value):
                state.avatar = value
                return .none
            case let .favoriteFoodChanged(value):
                state.favoriteFood = value
                return .none
            case .saveTapped:
                guard state.canSave else { return .none }
                state.isSaving = true
                let profile = ProfileSnapshot(
                    name: state.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    avatar: state.avatar,
                    favoriteFood: state.favoriteFood.trimmingCharacters(in: .whitespacesAndNewlines),
                    hasCompletedOnboarding: true
                )
                return .run { send in
                    await profileSettings.save(profile)
                    await send(.saved(profile))
                }
            case .saved:
                state.isSaving = false
                return .none
            case .close:
                return .none
            }
        }
    }
}
