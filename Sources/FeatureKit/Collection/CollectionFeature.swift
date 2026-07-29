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
        public var isEditing = false
        public var isDeleting = false
        public var isDeleteErrorPresented = false
        public var selectedCutoutIDs: Set<UUID> = []
        public var selectedCutoutID: UUID?
        public var cutoutMealInfo: [UUID: CutoutMealInfo] = [:]
        public var streak = MealStreak()
        public var recapStartDate: Date
        public var recapEndDate: Date
        @Presents public var achievements: AchievementsFeature.State?
        @Presents public var recap: RecapFeature.State?
        public init(
            recapStartDate: Date = Calendar.current.startOfDay(for: Date()),
            recapEndDate: Date = Calendar.current.startOfDay(for: Date())
        ) {
            self.recapStartDate = recapStartDate
            self.recapEndDate = recapEndDate
        }

        public var recapRangeText: String {
            let start = recapStartDate.formatted(
                .dateTime.year().month(.abbreviated).day()
            )
            if Calendar.current.isDate(recapStartDate, inSameDayAs: recapEndDate) {
                return start
            }
            let end = recapEndDate.formatted(
                .dateTime.year().month(.abbreviated).day()
            )
            return "\(start) – \(end)"
        }
    }

    public enum Action: Equatable {
        case onAppear
        case cutoutsLoaded([FoodEntrySnapshot])
        case mealInfoLoaded([UUID: CutoutMealInfo])
        case cutoutTapped(UUID)
        case dismissCutoutDetail
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
        case recapDateRangeChanged(start: Date, end: Date)
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
                state.selectedCutoutIDs.formIntersection(Set(cutouts.map(\.id)))
                if let selectedCutoutID = state.selectedCutoutID,
                   !cutouts.contains(where: { $0.id == selectedCutoutID }) {
                    state.selectedCutoutID = nil
                }
                if cutouts.isEmpty {
                    state.isEditing = false
                }
                return .none
            case let .mealInfoLoaded(info):
                state.cutoutMealInfo = info
                return .none
            case let .cutoutTapped(id):
                state.selectedCutoutID = id
                return .none
            case .dismissCutoutDetail:
                state.selectedCutoutID = nil
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
                    try await persistence.deleteEntries(ids)
                    await send(.cutoutsDeleted(ids))
                } catch: { _, send in
                    await send(.cutoutDeletionFailed)
                }
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
            case let .cutoutsDeleted(ids):
                state.cutouts.removeAll { ids.contains($0.id) }
                if let selectedCutoutID = state.selectedCutoutID,
                   ids.contains(selectedCutoutID) {
                    state.selectedCutoutID = nil
                }
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
            case let .recapDateRangeChanged(rawStart, rawEnd):
                state.recapStartDate = Calendar.current.startOfDay(
                    for: min(rawStart, rawEnd)
                )
                state.recapEndDate = Calendar.current.startOfDay(
                    for: max(rawStart, rawEnd)
                )
                return .none
            case .recapButtonTapped:
                state.recap = RecapFeature.State(
                    startDate: state.recapStartDate,
                    endDate: state.recapEndDate
                )
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
