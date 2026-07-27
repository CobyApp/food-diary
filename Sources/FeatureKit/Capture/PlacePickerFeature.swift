import ComposableArchitecture
import Models
import ClientKit

@Reducer
public struct PlacePickerFeature {
    @ObservableState
    public struct State: Equatable {
        public var coordinate: Coordinate?
        public var places: [PlaceInfo] = []
        public var isLoading = false
        public var isSearchFailed = false
        public var manualName = ""
        public var selected: PlaceInfo?
        public init(coordinate: Coordinate? = nil) { self.coordinate = coordinate }
    }

    public enum Action: Equatable {
        case task
        case placesLoaded([PlaceInfo])
        case searchFailed
        case placeSelected(PlaceInfo)
        case manualNameChanged(String)
        case useManualEntry
    }

    @Dependency(\.placeSearch) var placeSearch

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard let coordinate = state.coordinate else { return .none }
                state.isLoading = true
                state.isSearchFailed = false
                return .run { send in
                    let places = try await placeSearch.nearby(coordinate)
                    await send(.placesLoaded(places))
                } catch: { _, send in
                    await send(.searchFailed)
                }
            case let .placesLoaded(places):
                state.isLoading = false
                state.places = places
                return .none
            case .searchFailed:
                state.isLoading = false
                state.isSearchFailed = true
                return .none
            case let .placeSelected(place):
                state.selected = place
                return .none
            case let .manualNameChanged(name):
                state.manualName = name
                return .none
            case .useManualEntry:
                state.selected = PlaceInfo(id: "manual", name: state.manualName, address: "")
                return .none
            }
        }
    }
}
