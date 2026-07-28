import ClientKit
import ComposableArchitecture
import Foundation
import Models

@Reducer
public struct RecapFeature {
    @ObservableState
    public struct State: Equatable {
        public var weekCutouts: [CutoutSnapshot] = []
        public var mealCount = 0
        public var rangeText = ""
        public var isLoading = false
        /// Apple Intelligence's closing line; nil until it answers (or if it can't).
        public var caption: String?
        /// Keeps a late AI response from replacing the line the user already wrote.
        public var hasEditedCaption = false

        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
        case loaded(cutouts: [CutoutSnapshot], mealCount: Int, rangeText: String)
        case captionGenerated(String?)
        case captionChanged(String)
        case close
    }

    @Dependency(\.date.now) var now
    @Dependency(\.persistence) var persistence
    @Dependency(\.caption) var caption
    @Dependency(\.locale) var locale

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                let end = now
                let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
                let languageCode = locale.language.languageCode?.identifier ?? "en"
                return .run { send in
                    let meals = try await persistence.allMeals()
                    let week = meals.filter { $0.eatenAt >= start && $0.eatenAt <= end }
                    let range = "\(Self.shortDate(start))~\(Self.shortDate(end))"
                    await send(.loaded(
                        cutouts: week.flatMap(\.cutouts),
                        mealCount: week.count,
                        rangeText: range
                    ))
                    guard !week.isEmpty else { return }
                    let places = week.compactMap { $0.place?.name }.filter { !$0.isEmpty }
                    await send(.captionGenerated(
                        await caption.weeklyCaption(week.count, places, languageCode)
                    ))
                } catch: { _, send in
                    await send(.loaded(
                        cutouts: [],
                        mealCount: 0,
                        rangeText: "\(Self.shortDate(start))~\(Self.shortDate(end))"
                    ))
                }

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

    private static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits))
    }
}
