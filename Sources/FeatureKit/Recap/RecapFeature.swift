import ClientKit
import ComposableArchitecture
import Foundation
import Models

@Reducer
public struct RecapFeature {
    @ObservableState
    public struct State: Equatable {
        public var weekCutouts: [FoodEntrySnapshot] = []
        public var mealCount = 0
        public var rangeText = ""
        public var startDate: Date?
        public var endDate: Date?
        public var isLoading = false
        /// Apple Intelligence's closing line; nil until it answers (or if it can't).
        public var caption: String?
        /// Keeps a late AI response from replacing the line the user already wrote.
        public var hasEditedCaption = false

        public init(startDate: Date? = nil, endDate: Date? = nil) {
            self.startDate = startDate
            self.endDate = endDate
        }
    }

    public enum Action: Equatable {
        case onAppear
        case loaded(cutouts: [FoodEntrySnapshot], mealCount: Int, rangeText: String)
        case dateRangeChanged(start: Date, end: Date)
        case captionGenerated(String?)
        case captionChanged(String)
        case close
    }

    @Dependency(\.date.now) var now
    @Dependency(\.persistence) var persistence
    @Dependency(\.caption) var caption
    @Dependency(\.locale) var locale

    public init() {}

    private enum CancelID { case load }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let today = Calendar.current.startOfDay(for: now)
                let start = state.startDate ?? today
                let end = state.endDate ?? today
                state.startDate = start
                state.endDate = end
                state.isLoading = true
                state.rangeText = Self.rangeText(start: start, end: end)
                return load(start: start, end: end)

            case let .dateRangeChanged(rawStart, rawEnd):
                let start = Calendar.current.startOfDay(for: min(rawStart, rawEnd))
                let end = Calendar.current.startOfDay(for: max(rawStart, rawEnd))
                state.startDate = start
                state.endDate = end
                state.rangeText = Self.rangeText(start: start, end: end)
                state.isLoading = true
                state.caption = nil
                state.hasEditedCaption = false
                return load(start: start, end: end)

            case let .loaded(cutouts, mealCount, rangeText):
                state.isLoading = false
                state.weekCutouts = cutouts
                state.mealCount = mealCount
                state.rangeText = rangeText
                return .none

            case let .captionGenerated(line):
                if !state.hasEditedCaption {
                    state.caption = line
                }
                return .none

            case let .captionChanged(line):
                state.caption = String(line.prefix(60))
                state.hasEditedCaption = true
                return .none

            case .close:
                return .none
            }
        }
    }

    private func load(start: Date, end: Date) -> Effect<Action> {
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        let endExclusive = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
        let range = Self.rangeText(start: start, end: end)
        return .run { send in
            let entries = try await persistence.allEntries()
            let selected = entries.filter {
                $0.eatenAt >= start && $0.eatenAt < endExclusive
            }
            await send(.loaded(
                cutouts: selected,
                mealCount: selected.count,
                rangeText: range
            ))
            guard !selected.isEmpty else { return }
            let places = selected.compactMap { $0.place?.name }.filter { !$0.isEmpty }
            await send(.captionGenerated(
                await caption.weeklyCaption(selected.count, places, languageCode)
            ))
        } catch: { _, send in
            await send(.loaded(cutouts: [], mealCount: 0, rangeText: range))
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    private static func rangeText(start: Date, end: Date) -> String {
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return shortDate(start)
        }
        return "\(shortDate(start))~\(shortDate(end))"
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits))
    }
}
