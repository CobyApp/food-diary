import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct CollectionFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot] = []
        public var isLoading = false
        public var streak = MealStreak()
        @Presents public var achievements: AchievementsFeature.State?
        @Presents public var recap: RecapFeature.State?
        @Presents public var profile: ProfileFeature.State?
        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
        case cutoutsLoaded([CutoutSnapshot])
        case cutoutTapped(UUID)
        case streakOnAppear
        case streakLoaded(MealStreak)
        case achievementsButtonTapped
        case achievements(PresentationAction<AchievementsFeature.Action>)
        case recapButtonTapped
        case recap(PresentationAction<RecapFeature.Action>)
        case profileCheck
        case profileLoaded(ProfileSnapshot)
        case profileButtonTapped
        case profileEditorLoaded(ProfileSnapshot)
        case profile(PresentationAction<ProfileFeature.Action>)
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let cutouts = try await persistence.allCutouts()
                    await send(.cutoutsLoaded(cutouts))
                } catch: { _, send in
                    await send(.cutoutsLoaded([]))
                }
            case let .cutoutsLoaded(cutouts):
                state.isLoading = false
                state.cutouts = cutouts
                return .none
            case .cutoutTapped:
                // Navigation handled by the parent (RootFeature).
                return .none
            case .streakOnAppear:
                return .run { [now = Date()] send in
                    let meals = try await persistence.allMeals()
                    await send(.streakLoaded(.calculate(meals: meals, now: now)))
                } catch: { _, send in
                    await send(.streakLoaded(MealStreak()))
                }
            case let .streakLoaded(streak):
                state.streak = streak
                return .none
            case .achievementsButtonTapped:
                state.achievements = AchievementsFeature.State()
                return .none
            case .achievements(.presented(.close)):
                state.achievements = nil
                return .none
            case .achievements:
                return .none
            case .recapButtonTapped:
                state.recap = RecapFeature.State()
                return .none
            case .recap(.presented(.close)):
                state.recap = nil
                return .none
            case .recap:
                return .none
            case .profileCheck:
                return .run { send in
                    await send(.profileLoaded(profileSettings.load()))
                }
            case let .profileLoaded(profile):
                if !profile.hasCompletedOnboarding {
                    state.profile = ProfileFeature.State(profile: profile, isOnboarding: true)
                }
                return .none
            case .profileButtonTapped:
                return .run { send in
                    await send(.profileEditorLoaded(profileSettings.load()))
                }
            case let .profileEditorLoaded(profile):
                state.profile = ProfileFeature.State(profile: profile)
                return .none
            case .profile(.presented(.saved)), .profile(.presented(.close)):
                state.profile = nil
                return .none
            case .profile:
                return .none
            }
        }
        .ifLet(\.$achievements, action: \.achievements) {
            AchievementsFeature()
        }
        .ifLet(\.$recap, action: \.recap) {
            RecapFeature()
        }
        .ifLet(\.$profile, action: \.profile) {
            ProfileFeature()
        }
    }

    @Dependency(\.profileSettings) var profileSettings
}
