import ComposableArchitecture
import Foundation
import Models
import ClientKit

public struct CutoutMealInfo: Equatable, Sendable {
    public let placeName: String
    public let dateText: String
    public let tags: [String]
    public let rating: Int?
    public init(placeName: String, dateText: String, tags: [String], rating: Int?) {
        self.placeName = placeName
        self.dateText = dateText
        self.tags = tags
        self.rating = rating
    }
}

@Reducer
public struct CollectionFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [FoodEntrySnapshot] = []
        public var isLoading = false
        public var isDeleting = false
        public var isDeleteErrorPresented = false
        /// The sticker whose card is showing, the way a tapped map pin opens one.
        public var selectedCutoutID: UUID?
        public var cutoutMealInfo: [UUID: CutoutMealInfo] = [:]
        public var streak = MealStreak()
        @Presents public var achievements: AchievementsFeature.State?
        @Presents public var recap: RecapFeature.State?
        public init(
        ) {}

    }

    public enum Action: Equatable {
        case onAppear
        case cutoutsLoaded([FoodEntrySnapshot])
        case mealInfoLoaded([UUID: CutoutMealInfo])
        case deleteCutoutsConfirmed(Set<UUID>)
        case cutoutTapped(UUID)
        case dismissCutoutDetail
        case cutoutsDeleted(Set<UUID>)
        case cutoutDeletionFailed
        case dismissDeleteError
        case streakOnAppear
        case streakLoaded(MealStreak)
        case achievementsButtonTapped
        case achievements(PresentationAction<AchievementsFeature.Action>)
        case recapButtonTapped([FoodEntrySnapshot])
        case recap(PresentationAction<RecapFeature.Action>)
    }

    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let entries = try await persistence.allEntries()
                    await send(.cutoutsLoaded(entries))
                    // Each food carries its own information now, so this is just
                    // an index for the views rather than a lookup across records.
                    var info: [UUID: CutoutMealInfo] = [:]
                    for entry in entries {
                        info[entry.id] = CutoutMealInfo(
                            placeName: entry.place?.name ?? "",
                            dateText: entry.eatenAt.formatted(.dateTime.month().day()),
                            tags: entry.tags,
                            rating: entry.rating
                        )
                    }
                    await send(.mealInfoLoaded(info))
                } catch: { _, send in
                    await send(.cutoutsLoaded([]))
                }
            case let .cutoutsLoaded(cutouts):
                state.isLoading = false
                state.cutouts = cutouts
                if let selected = state.selectedCutoutID,
                   !cutouts.contains(where: { $0.id == selected }) {
                    state.selectedCutoutID = nil
                }
                return .none
            case let .mealInfoLoaded(info):
                state.cutoutMealInfo = info
                return .none
            case let .deleteCutoutsConfirmed(ids):
                let validIDs = ids.intersection(Set(state.cutouts.map(\.id)))
                guard !validIDs.isEmpty, !state.isDeleting else { return .none }
                state.isDeleting = true
                return .run { send in
                    try await persistence.deleteEntries(validIDs)
                    await send(.cutoutsDeleted(validIDs))
                } catch: { _, send in
                    await send(.cutoutDeletionFailed)
                }
            case let .cutoutTapped(id):
                state.selectedCutoutID = state.selectedCutoutID == id ? nil : id
                return .none
            case .dismissCutoutDetail:
                state.selectedCutoutID = nil
                return .none
            case let .cutoutsDeleted(ids):
                state.cutouts.removeAll { ids.contains($0.id) }
                if let selected = state.selectedCutoutID, ids.contains(selected) {
                    state.selectedCutoutID = nil
                }
                state.isDeleting = false
                return .none
            case .cutoutDeletionFailed:
                state.isDeleting = false
                state.isDeleteErrorPresented = true
                return .none
            case .dismissDeleteError:
                state.isDeleteErrorPresented = false
                return .none
            case .streakOnAppear:
                return .run { [now = Date()] send in
                    let entries = try await persistence.allEntries()
                    await send(.streakLoaded(.calculate(entries: entries, now: now)))
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
            case let .recapButtonTapped(cutouts):
                // Whatever is on the board right now is the recap.
                state.recap = RecapFeature.State(cutouts: cutouts)
                return .none
            case .recap(.presented(.close)):
                state.recap = nil
                return .none
            case .recap:
                return .none
            }
        }
        .ifLet(\.$achievements, action: \.achievements) {
            AchievementsFeature()
        }
        .ifLet(\.$recap, action: \.recap) {
            RecapFeature()
        }
    }
}
