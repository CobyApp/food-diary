import SwiftUI
import PhotosUI
import ComposableArchitecture

public struct CaptureView: View {
    @Bindable var store: StoreOf<CaptureFeature>
    @State private var pickerItem: PhotosPickerItem?
    public init(store: StoreOf<CaptureFeature>) { self.store = store }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("음식 사진 고르기", systemImage: "camera")
                    }
                }
                if store.isProcessing { ProgressView("음식 누끼 따는 중…") }

                if !store.candidates.isEmpty {
                    Section("담을 누끼 고르기") {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(store.candidates) { candidate in
                                    Button { store.send(.toggleCandidate(candidate.id)) } label: {
                                        CutoutImage(data: candidate.pngData)
                                            .frame(width: 90, height: 90)
                                            .overlay(alignment: .topTrailing) {
                                                Image(systemName: candidate.isSelected
                                                      ? "checkmark.circle.fill" : "circle")
                                                    .padding(4)
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Section("한 끼 정보") {
                        Button {
                            store.send(.choosePlaceTapped)
                        } label: {
                            HStack {
                                Text("식당")
                                Spacer()
                                Text(store.placePicker?.selected?.name ?? "선택 안 함")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        TextField("메모", text: Binding(
                            get: { store.memo },
                            set: { store.send(.memoChanged($0)) }
                        ))
                        Stepper("별점: \(store.rating.map(String.init) ?? "-")",
                                value: Binding(
                                    get: { store.rating ?? 0 },
                                    set: { store.send(.ratingChanged($0)) }
                                ), in: 0...5)
                    }
                    Section {
                        Button("다이어리에 저장") { store.send(.saveTapped) }
                            .disabled(!store.candidates.contains(where: \.isSelected))
                    }
                }
            }
            .navigationTitle("한 끼 담기")
            .sheet(item: $store.scope(state: \.placePicker, action: \.placePicker)) { pickerStore in
                NavigationStack { PlacePickerView(store: pickerStore) }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        store.send(.photoPicked(data))
                    }
                }
            }
        }
    }
}
