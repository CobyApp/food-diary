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
        /// This food's own tags and rating — not the batch's.
        public var tags: [String]
        public var rating: Int?
        public init(
            id: UUID = UUID(),
            pngData: Data,
            isSelected: Bool = true,
            decoration: CutoutDecoration = .none,
            isRotating: Bool = false,
            tags: [String] = [],
            rating: Int? = nil
        ) {
            self.id = id
            self.pngData = pngData
            self.isSelected = isSelected
            self.decoration = decoration
            self.isRotating = isRotating
            self.tags = tags
            self.rating = rating
        }
    }

    /// Capture is a short wizard, one thing per screen. Doing it all on a single
    /// screen meant the sources, the cutouts, the tags and the restaurant were all
    /// competing for the same space.
    public enum Step: Int, Equatable, Sendable, CaseIterable {
        case source
        case cutouts
        case details
        case finish
    }

    @ObservableState
    public struct State: Equatable {
        public var step: Step = .source
        public var coordinate: Coordinate?
        public var candidates: [CutoutCandidate]
        public var isProcessing = false
        public var processingCompleted = 0
        public var processingTotal = 0
        public var isSaving = false
        public var isSaveErrorPresented = false
        public var isCameraPresented = false
        /// Shown when iOS has already been told no: it will not ask again.
        public var isCameraDeniedPresented = false
        /// The food whose information is being filled in, if that sheet is open.
        public var editingCandidateID: UUID?
        /// Every tag the user has ever made, so they can be reused.
        public var tagCatalog: [String] = []
        public var newTagText = ""
        /// The tag being renamed, if the rename sheet is up.
        public var renamingTag: String?
        public var renameText = ""
        @Presents public var placePicker: PlacePickerFeature.State?
        public var chosenPlace: PlaceInfo?
        public var savedEntries: [FoodEntrySnapshot] = []

        var editingIndex: Int? {
            guard let editingCandidateID else { return nil }
            return candidates.firstIndex { $0.id == editingCandidateID }
        }

        /// The food currently being described.
        public var editingCandidate: CutoutCandidate? {
            editingIndex.map { candidates[$0] }
        }

        /// Only what is actually being saved gets described.
        public var selectedCandidates: [CutoutCandidate] {
            candidates.filter(\.isSelected)
        }

        public init(
            coordinate: Coordinate? = nil,
            candidates: [CutoutCandidate] = [],
            chosenPlace: PlaceInfo? = nil
        ) {
            self.coordinate = coordinate
            self.candidates = candidates
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
        case nextStep
        case previousStep
        case cameraTapped
        case cameraAccessResolved(CameraAccess)
        case cameraDismissed
        case dismissCameraDenied
        case editCandidateTapped(UUID)
        case dismissCandidateEditor
        case tagsOnAppear
        case tagCatalogLoaded([String])
        case tagToggled(String)
        case newTagTextChanged(String)
        case newTagSubmitted
        case renameTagRequested(String)
        case renameTextChanged(String)
        case renameConfirmed
        case renameCancelled
        case deleteTagRequested(String)
        case ratingChanged(Int?)
        case choosePlaceTapped
        case placePicker(PresentationAction<PlacePickerFeature.Action>)
        case saveTapped
        case saved([FoodEntrySnapshot])
        case saveFailed
        case dismissSaveError
    }

    @Dependency(\.foodCutout) var foodCutout
    @Dependency(\.photoLocation) var photoLocation
    @Dependency(\.persistence) var persistence
    @Dependency(\.cameraAccess) var cameraAccess

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
                // Extracting is the point of picking a photo, so move straight on.
                if !state.candidates.isEmpty, state.step == .source {
                    state.step = .cutouts
                }
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

            case .tagsOnAppear:
                return .run { send in
                    await send(.tagCatalogLoaded((try? await persistence.allTags()) ?? []))
                }

            case let .tagCatalogLoaded(tags):
                state.tagCatalog = tags
                return .none

            case .nextStep:
                switch state.step {
                case .source:
                    guard !state.candidates.isEmpty else { return .none }
                    state.step = .cutouts
                case .cutouts:
                    guard state.candidates.contains(where: \.isSelected) else { return .none }
                    state.step = .details
                    // Open on the first food the user actually kept.
                    state.editingCandidateID = state.candidates.first(where: \.isSelected)?.id
                case .details:
                    state.step = .finish
                case .finish:
                    return .none
                }
                return .none

            case .previousStep:
                switch state.step {
                case .source: return .none
                case .cutouts: state.step = .source
                case .details: state.step = .cutouts
                case .finish: state.step = .details
                }
                return .none

            case .cameraTapped:
                return .run { send in
                    await send(.cameraAccessResolved(await cameraAccess.request()))
                }

            case let .cameraAccessResolved(access):
                switch access {
                case .granted: state.isCameraPresented = true
                case .denied: state.isCameraDeniedPresented = true
                }
                return .none

            case .cameraDismissed:
                state.isCameraPresented = false
                return .none

            case .dismissCameraDenied:
                state.isCameraDeniedPresented = false
                return .none

            case let .editCandidateTapped(id):
                state.editingCandidateID = id
                return .none

            case .dismissCandidateEditor:
                state.editingCandidateID = nil
                return .none

            case let .tagToggled(name):
                guard let name = TagName.normalize(name),
                      let index = state.editingIndex else { return .none }
                if let existing = state.candidates[index].tags
                    .firstIndex(where: { TagName.isSame($0, name) }) {
                    state.candidates[index].tags.remove(at: existing)
                } else {
                    state.candidates[index].tags.append(name)
                }
                return .none

            case let .newTagTextChanged(text):
                state.newTagText = text
                return .none

            case .newTagSubmitted:
                guard let name = TagName.normalize(state.newTagText) else {
                    state.newTagText = ""
                    return .none
                }
                state.newTagText = ""
                // Picked straight away: typing a tag out is how you say you want it.
                if let index = state.editingIndex,
                   !state.candidates[index].tags.contains(where: { TagName.isSame($0, name) }) {
                    state.candidates[index].tags.append(name)
                }
                return .run { send in
                    try? await persistence.createTag(name)
                    await send(.tagCatalogLoaded((try? await persistence.allTags()) ?? []))
                }

            case let .renameTagRequested(name):
                state.renamingTag = name
                state.renameText = name
                return .none

            case let .renameTextChanged(text):
                state.renameText = text
                return .none

            case .renameConfirmed:
                guard let old = state.renamingTag,
                      let new = TagName.normalize(state.renameText),
                      !TagName.isSame(old, new) else {
                    state.renamingTag = nil
                    return .none
                }
                state.renamingTag = nil
                // Keep every food's picks in step with the catalog.
                for index in state.candidates.indices {
                    state.candidates[index].tags = TagName.cleaned(
                        state.candidates[index].tags.map { TagName.isSame($0, old) ? new : $0 }
                    )
                }
                return .run { send in
                    try? await persistence.renameTag(old, new)
                    await send(.tagCatalogLoaded((try? await persistence.allTags()) ?? []))
                }

            case .renameCancelled:
                state.renamingTag = nil
                return .none

            case let .deleteTagRequested(name):
                for index in state.candidates.indices {
                    state.candidates[index].tags.removeAll { TagName.isSame($0, name) }
                }
                return .run { send in
                    try? await persistence.deleteTag(name)
                    await send(.tagCatalogLoaded((try? await persistence.allTags()) ?? []))
                }

            case let .ratingChanged(rating):
                guard let index = state.editingIndex else { return .none }
                state.candidates[index].rating = rating
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
                // One record per food, each with the information it was given.
                let selected = state.candidates
                    .filter(\.isSelected)
                    .map {
                        NewEntry(
                            pngData: $0.pngData,
                            label: $0.decoration.label,
                            tags: $0.tags,
                            rating: $0.rating
                        )
                    }
                guard !selected.isEmpty else {
                    state.isSaving = false
                    return .none
                }
                return .run { send in
                    let entries = try await persistence.saveEntries(place, selected)
                    await send(.saved(entries))
                } catch: { _, send in
                    await send(.saveFailed)
                }

            case let .saved(entries):
                // The catalog outlives one batch, so it survives the reset.
                let catalog = state.tagCatalog
                state = State()
                state.tagCatalog = catalog
                state.savedEntries = entries
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
