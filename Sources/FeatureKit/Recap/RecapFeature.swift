import ClientKit
import ComposableArchitecture
import Foundation
import Models

@Reducer
public struct RecapFeature {
    @ObservableState
    public struct State: Equatable {
        /// The board exactly as it stands. A recap is a picture of the main
        /// screen, so there is no range to pick and no query to run.
        public var cutouts: [FoodEntrySnapshot]
        /// Apple Intelligence's closing line; nil until it answers (or if it can't).
        public var caption: String?
        /// Keeps a late AI response from replacing the line the user already wrote.
        public var hasEditedCaption = false

        public init(cutouts: [FoodEntrySnapshot] = []) {
            self.cutouts = cutouts
        }

        public var mealCount: Int { cutouts.count }
    }

    public enum Action: Equatable {
        case onAppear
        case captionGenerated(String?)
        case captionChanged(String)
        case close
    }

    @Dependency(\.caption) var caption
    @Dependency(\.locale) var locale

    public init() {}

    private enum CancelID { case caption }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let cutouts = state.cutouts
                guard !cutouts.isEmpty else { return .none }
                let languageCode = locale.language.languageCode?.identifier ?? "en"
                let places = cutouts.compactMap { $0.place?.name }.filter { !$0.isEmpty }
                return .run { send in
                    await send(.captionGenerated(
                        await caption.weeklyCaption(cutouts.count, places, languageCode)
                    ))
                }
                .cancellable(id: CancelID.caption, cancelInFlight: true)

            case let .captionGenerated(line):
                // A line the user typed themselves outranks a late arrival.
                guard !state.hasEditedCaption else { return .none }
                state.caption = line
                return .none

            case let .captionChanged(text):
                state.hasEditedCaption = true
                state.caption = text.isEmpty ? nil : text
                return .none

            case .close:
                return .none
            }
        }
    }
}
