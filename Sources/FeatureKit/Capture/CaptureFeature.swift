import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct CaptureFeature {
    public struct CutoutCandidate: Equatable, Identifiable {
        public let id: UUID
        public let pngData: Data
        public var isSelected: Bool
        public init(id: UUID = UUID(), pngData: Data, isSelected: Bool = true) {
            self.id = id
            self.pngData = pngData
            self.isSelected = isSelected
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var photoData: Data?
        public var coordinate: Coordinate?
        public var candidates: [CutoutCandidate]
        public var isProcessing = false
        public var memo: String
        public var rating: Int?
        @Presents public var placePicker: PlacePickerFeature.State?
        public var savedMeal: MealSnapshot?

        public init(
            photoData: Data? = nil,
            coordinate: Coordinate? = nil,
            candidates: [CutoutCandidate] = [],
            memo: String = "",
            rating: Int? = nil
        ) {
            self.photoData = photoData
            self.coordinate = coordinate
            self.candidates = candidates
            self.memo = memo
            self.rating = rating
        }

        public var selectedPlace: PlaceInfo? { placePicker?.selected }
    }

    public enum Action: Equatable {
        case photoPicked(Data)
        case processingFinished(coordinate: Coordinate?, cutouts: [Data])
        case toggleCandidate(UUID)
        case memoChanged(String)
        case ratingChanged(Int?)
        case choosePlaceTapped
        case placePicker(PresentationAction<PlacePickerFeature.Action>)
        case saveTapped
        case saved(MealSnapshot)
    }

    @Dependency(\.foodCutout) var foodCutout
    @Dependency(\.photoLocation) var photoLocation
    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .photoPicked(data):
                state.photoData = data
                state.isProcessing = true
                return .run { send in
                    async let cutouts = foodCutout.extract(data)
                    let coordinate = photoLocation.coordinate(data)
                    let pngs = try await cutouts.map(\.pngData)
                    await send(.processingFinished(coordinate: coordinate, cutouts: pngs))
                } catch: { _, send in
                    // Extraction can fail (e.g. Vision has no inference context in
                    // the simulator); end processing with no candidates instead of
                    // leaving the spinner stuck forever.
                    await send(.processingFinished(coordinate: nil, cutouts: []))
                }

            case let .processingFinished(coordinate, cutouts):
                state.isProcessing = false
                state.coordinate = coordinate
                state.candidates = cutouts.map { CutoutCandidate(pngData: $0, isSelected: true) }
                return .none

            case let .toggleCandidate(id):
                guard let idx = state.candidates.firstIndex(where: { $0.id == id }) else { return .none }
                state.candidates[idx].isSelected.toggle()
                return .none

            case let .memoChanged(memo):
                state.memo = memo
                return .none

            case let .ratingChanged(rating):
                state.rating = rating
                return .none

            case .choosePlaceTapped:
                state.placePicker = PlacePickerFeature.State(coordinate: state.coordinate)
                return .none

            case .placePicker:
                return .none

            case .saveTapped:
                let place = state.placePicker?.selected
                let memo = state.memo
                let rating = state.rating
                let selected = state.candidates
                    .filter(\.isSelected)
                    .map { NewCutout(pngData: $0.pngData, label: nil) }
                return .run { send in
                    let meal = try await persistence.saveMeal(place, memo, rating, selected)
                    await send(.saved(meal))
                }

            case let .saved(meal):
                state.savedMeal = meal
                return .none
            }
        }
        .ifLet(\.$placePicker, action: \.placePicker) {
            PlacePickerFeature()
        }
    }
}
