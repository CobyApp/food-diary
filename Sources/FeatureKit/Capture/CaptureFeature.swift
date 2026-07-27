import ComposableArchitecture
import Foundation
import Models
import ClientKit

@Reducer
public struct CaptureFeature {
    public struct CutoutCandidate: Equatable, Identifiable {
        public let id: UUID
        public var pngData: Data
        public var isSelected: Bool
        public var decoration: CutoutDecoration
        public var isRotating: Bool
        public init(
            id: UUID = UUID(),
            pngData: Data,
            isSelected: Bool = true,
            decoration: CutoutDecoration = .none,
            isRotating: Bool = false
        ) {
            self.id = id
            self.pngData = pngData
            self.isSelected = isSelected
            self.decoration = decoration
            self.isRotating = isRotating
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var coordinate: Coordinate?
        public var candidates: [CutoutCandidate]
        public var isProcessing = false
        public var processingCompleted = 0
        public var processingTotal = 0
        public var isSaving = false
        public var isSaveErrorPresented = false
        public var memo: String
        public var rating: Int?
        @Presents public var placePicker: PlacePickerFeature.State?
        public var chosenPlace: PlaceInfo?
        public var savedMeal: MealSnapshot?

        public init(
            coordinate: Coordinate? = nil,
            candidates: [CutoutCandidate] = [],
            memo: String = "",
            rating: Int? = nil,
            chosenPlace: PlaceInfo? = nil
        ) {
            self.coordinate = coordinate
            self.candidates = candidates
            self.memo = memo
            self.rating = rating
            self.chosenPlace = chosenPlace
        }
    }

    public enum Action: Equatable {
        case photoPicked(Data)
        case photosPicked([Data])
        case photoProcessingProgress(completed: Int, total: Int)
        case processingFinished(coordinate: Coordinate?, cutouts: [Data])
        case toggleCandidate(UUID)
        case cycleDecoration(UUID)
        case rotateCandidate(UUID)
        case rotationFinished(id: UUID, pngData: Data?)
        case memoChanged(String)
        case ratingChanged(Int?)
        case choosePlaceTapped
        case placePicker(PresentationAction<PlacePickerFeature.Action>)
        case saveTapped
        case saved(MealSnapshot)
        case saveFailed
        case dismissSaveError
    }

    @Dependency(\.foodCutout) var foodCutout
    @Dependency(\.photoLocation) var photoLocation
    @Dependency(\.persistence) var persistence

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .photoPicked(data):
                return processPhotos([data], state: &state)

            case let .photosPicked(data):
                return processPhotos(data, state: &state)

            case let .photoProcessingProgress(completed, total):
                state.processingCompleted = completed
                state.processingTotal = total
                return .none

            case let .processingFinished(coordinate, cutouts):
                state.isProcessing = false
                state.processingCompleted = 0
                state.processingTotal = 0
                if state.coordinate == nil {
                    state.coordinate = coordinate
                }
                state.candidates.append(
                    contentsOf: cutouts.map {
                        CutoutCandidate(pngData: $0, isSelected: true)
                    }
                )
                return .none

            case let .toggleCandidate(id):
                guard let idx = state.candidates.firstIndex(where: { $0.id == id }) else { return .none }
                state.candidates[idx].isSelected.toggle()
                return .none

            case let .cycleDecoration(id):
                guard let idx = state.candidates.firstIndex(where: { $0.id == id }) else { return .none }
                state.candidates[idx].decoration = state.candidates[idx].decoration.next
                return .none

            case let .rotateCandidate(id):
                guard
                    let idx = state.candidates.firstIndex(where: { $0.id == id }),
                    !state.candidates[idx].isRotating
                else { return .none }
                state.candidates[idx].isRotating = true
                let data = state.candidates[idx].pngData
                return .run { send in
                    let rotated = await foodCutout.rotateClockwise(data)
                    await send(.rotationFinished(id: id, pngData: rotated))
                }

            case let .rotationFinished(id, pngData):
                guard let idx = state.candidates.firstIndex(where: { $0.id == id }) else {
                    return .none
                }
                state.candidates[idx].isRotating = false
                if let pngData {
                    state.candidates[idx].pngData = pngData
                }
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

            case .placePicker(.presented(.placeSelected)), .placePicker(.presented(.useManualEntry)):
                state.chosenPlace = state.placePicker?.selected
                state.placePicker = nil
                return .none

            case .placePicker:
                return .none

            case .saveTapped:
                guard !state.isSaving, !state.candidates.contains(where: \.isRotating) else {
                    return .none
                }
                state.isSaving = true
                let place = state.chosenPlace
                let memo = state.memo
                let rating = state.rating
                let selected = state.candidates
                    .filter(\.isSelected)
                    .map { NewCutout(pngData: $0.pngData, label: $0.decoration.label) }
                return .run { send in
                    let meal = try await persistence.saveMeal(place, memo, rating, selected)
                    await send(.saved(meal))
                } catch: { _, send in
                    await send(.saveFailed)
                }

            case let .saved(meal):
                state = State()
                state.savedMeal = meal
                return .none

            case .saveFailed:
                state.isSaving = false
                state.isSaveErrorPresented = true
                return .none

            case .dismissSaveError:
                state.isSaveErrorPresented = false
                return .none
            }
        }
        .ifLet(\.$placePicker, action: \.placePicker) {
            PlacePickerFeature()
        }
    }

    private func processPhotos(
        _ data: [Data],
        state: inout State
    ) -> Effect<Action> {
        guard !data.isEmpty, !state.isProcessing else { return .none }
        state.isProcessing = true
        state.processingCompleted = 0
        state.processingTotal = data.count

        return .run { send in
            var allCutouts: [Data] = []
            var firstCoordinate: Coordinate?

            for (index, photoData) in data.enumerated() {
                if firstCoordinate == nil {
                    firstCoordinate = photoLocation.coordinate(photoData)
                }
                if let cutouts = try? await foodCutout.extract(photoData) {
                    allCutouts.append(contentsOf: cutouts.map(\.pngData))
                }
                await send(.photoProcessingProgress(
                    completed: index + 1,
                    total: data.count
                ))
            }

            await send(.processingFinished(
                coordinate: firstCoordinate,
                cutouts: allCutouts
            ))
        }
    }
}
