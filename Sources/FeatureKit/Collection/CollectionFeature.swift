import ComposableArchitecture
import Foundation
import Models
import ClientKit

public struct CutoutMealInfo: Equatable, Sendable {
    public let placeName: String
    public let dateText: String
    public let memo: String
    public init(placeName: String, dateText: String, memo: String) {
        self.placeName = placeName; self.dateText = dateText; self.memo = memo
    }
}

@Reducer
public struct CollectionFeature {
    @ObservableState
    public struct State: Equatable {
        public var cutouts: [CutoutSnapshot] = []
        public var isLoading = false
        public var isEditing = false
        public var isDeleting = false
        public var isDeleteErrorPresented = false
        public var selectedCutoutIDs: Set<UUID> = []
        public var flippedCutoutID: UUID?
        public var cutoutMealInfo: [UUID: CutoutMealInfo] = [:]
        public var streak = MealStreak()
        @Presents public var achievements: AchievementsFeature.State?
        @Presents public var recap: RecapFeature.State?
        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
        case cutoutsLoaded([CutoutSnapshot])
        case mealInfoLoaded([UUID: CutoutMealInfo])
        case cutoutTapped(UUID)
        case editButtonTapped
        case beginSelection(UUID)
        case selectionToggled(UUID)
        case selectAllTapped
        case deleteSelectedConfirmed
        case deleteCutoutsConfirmed(Set<UUID>)
        case cutoutsDeleted(Set<UUID>)
        case cutoutDeletionFailed
        case dismissDeleteError
        case streakOnAppear
        case streakLoaded(MealStreak)
        case achievementsButtonTapped
        case achievements(PresentationAction<AchievementsFeature.Action>)
        case recapButtonTapped
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
                    let cutouts = try await persistence.allCutouts()
                    await send(.cutoutsLoaded(cutouts))
                    let meals = (try? await persistence.allMeals()) ?? []
                    var info: [UUID: CutoutMealInfo] = [:]
                    for meal in meals {
                        let dateText = meal.eatenAt.formatted(.dateTime.month().day())
                        for c in meal.cutouts {
                            info[c.id] = CutoutMealInfo(
                                placeName: meal.place?.name ?? "",
                                dateText: dateText,
                                memo: meal.memo
                            )
                        }
                    }
                    await send(.mealInfoLoaded(info))
                } catch: { _, send in
                    await send(.cutoutsLoaded([]))
                }
            case let .cutoutsLoaded(cutouts):
                state.isLoading = false
                state.cutouts = cutouts
                state.selectedCutoutIDs.formIntersection(Set(cutouts.map(\.id)))
                if cutouts.isEmpty {
                    state.isEditing = false
                }
                return .none
            case let .mealInfoLoaded(info):
                state.cutoutMealInfo = info
                return .none
            case let .cutoutTapped(id):
                state.flippedCutoutID = (state.flippedCutoutID == id) ? nil : id
                return .none
            case .editButtonTapped:
                state.isEditing.toggle()
                state.selectedCutoutIDs.removeAll()
                return .none
            case let .beginSelection(id):
                guard state.cutouts.contains(where: { $0.id == id }) else { return .none }
                state.isEditing = true
                state.selectedCutoutIDs = [id]
                return .none
            case let .selectionToggled(id):
                guard state.isEditing, state.cutouts.contains(where: { $0.id == id }) else {
                    return .none
                }
                if state.selectedCutoutIDs.contains(id) {
                    state.selectedCutoutIDs.remove(id)
                } else {
                    state.selectedCutoutIDs.insert(id)
                }
                return .none
            case .selectAllTapped:
                guard state.isEditing else { return .none }
                let allIDs = Set(state.cutouts.map(\.id))
                state.selectedCutoutIDs = state.selectedCutoutIDs == allIDs ? [] : allIDs
                return .none
            case .deleteSelectedConfirmed:
                let ids = state.selectedCutoutIDs
                guard !ids.isEmpty, !state.isDeleting else { return .none }
                state.isDeleting = true
                return .run { send in
                    try await persistence.deleteCutouts(ids)
                    await send(.cutoutsDeleted(ids))
                } catch: { _, send in
                    await send(.cutoutDeletionFailed)
                }
            case let .deleteCutoutsConfirmed(ids):
                let validIDs = ids.intersection(Set(state.cutouts.map(\.id)))
                guard !validIDs.isEmpty, !state.isDeleting else { return .none }
                state.isDeleting = true
                return .run { send in
                    try await persistence.deleteCutouts(validIDs)
                    await send(.cutoutsDeleted(validIDs))
                } catch: { _, send in
                    await send(.cutoutDeletionFailed)
                }
            case let .cutoutsDeleted(ids):
                state.cutouts.removeAll { ids.contains($0.id) }
                state.selectedCutoutIDs.removeAll()
                state.isDeleting = false
                state.isEditing = false
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
