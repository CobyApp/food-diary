import SwiftUI
import ComposableArchitecture

public struct PlacePickerView: View {
    @Bindable var store: StoreOf<PlacePickerFeature>
    public init(store: StoreOf<PlacePickerFeature>) { self.store = store }

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("근처 식당").font(.appSection).foregroundStyle(.appMuted)
                    VStack(spacing: 10) {
                        ForEach(store.places) { place in
                            Button { store.send(.placeSelected(place)) } label: {
                                SoftCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(place.name).font(.appSection).foregroundStyle(.appInk)
                                            Text(place.address).font(.appCaption).foregroundStyle(.appMuted)
                                        }
                                        Spacer()
                                        if store.selected?.id == place.id {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.appBlue)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("직접 입력").font(.appSection).foregroundStyle(.appMuted).padding(.top, 4)
                    SoftCard {
                        TextField("식당 이름", text: Binding(
                            get: { store.manualName },
                            set: { store.send(.manualNameChanged($0)) }
                        ))
                        .font(.appBody)
                    }
                    PillButton("이 이름으로 사용", enabled: !store.manualName.isEmpty) {
                        store.send(.useManualEntry)
                    }
                }
                .padding(18)
            }
            if store.isLoading { ProgressView().tint(.appBlue) }
        }
        .navigationTitle("식당 선택")
        .navigationBarTitleDisplayMode(.inline)
        .task { store.send(.task) }
    }
}
