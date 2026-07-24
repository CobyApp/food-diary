import SwiftUI
import ComposableArchitecture

public struct PlacePickerView: View {
    @Bindable var store: StoreOf<PlacePickerFeature>
    public init(store: StoreOf<PlacePickerFeature>) { self.store = store }

    public var body: some View {
        List {
            Section("근처 식당") {
                ForEach(store.places) { place in
                    Button {
                        store.send(.placeSelected(place))
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(place.name)
                                Text(place.address).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.selected?.id == place.id {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Section("직접 입력") {
                TextField("식당 이름", text: Binding(
                    get: { store.manualName },
                    set: { store.send(.manualNameChanged($0)) }
                ))
                Button("이 이름으로 사용") { store.send(.useManualEntry) }
                    .disabled(store.manualName.isEmpty)
            }
        }
        .overlay { if store.isLoading { ProgressView() } }
        .navigationTitle("식당 선택")
        .task { store.send(.task) }
    }
}
