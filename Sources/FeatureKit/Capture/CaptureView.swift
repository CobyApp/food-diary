import SwiftUI
import PhotosUI
import ComposableArchitecture

public struct CaptureView: View {
    @Bindable var store: StoreOf<CaptureFeature>
    @State private var pickerItem: PhotosPickerItem?
    public init(store: StoreOf<CaptureFeature>) { self.store = store }

    private let candidateColumns = [GridItem(.adaptive(minimum: 90), spacing: 10)]

    public var body: some View {
        NavigationStack {
            ScreenScaffold(title: "한 끼 담기", doodle: nil) {
                VStack(alignment: .leading, spacing: 16) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        DropZoneCard { Label("음식 사진 고르기", systemImage: "camera") }
                    }
                    .buttonStyle(.plain)

                    if store.isProcessing {
                        HStack(spacing: 8) {
                            ProgressView().tint(.appBlue)
                            Text("음식 누끼 따는 중…").font(.appBody).foregroundStyle(.appMuted)
                        }
                    }

                    if !store.candidates.isEmpty {
                        Text("담을 누끼 고르기").font(.appSection).foregroundStyle(.appInk)
                        LazyVGrid(columns: candidateColumns, spacing: 10) {
                            ForEach(Array(store.candidates.enumerated()), id: \.element.id) { index, candidate in
                                Button { store.send(.toggleCandidate(candidate.id)) } label: {
                                    StickerTile(tint: .rotating(index)) {
                                        CutoutImage(data: candidate.pngData)
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(candidate.isSelected ? Color.appBlue : Color.appMuted)
                                            .padding(6)
                                    }
                                    .opacity(candidate.isSelected ? 1 : 0.5)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        SoftCard {
                            VStack(spacing: 12) {
                                Button { store.send(.choosePlaceTapped) } label: {
                                    HStack {
                                        Text("식당").font(.appSection).foregroundStyle(.appInk)
                                        Spacer()
                                        PastelChip(store.chosenPlace?.name ?? "선택 안 함",
                                                   glyph: "✦", tone: .blue)
                                    }
                                }
                                .buttonStyle(.plain)
                                Divider()
                                HStack {
                                    Text("메모").font(.appSection).foregroundStyle(.appInk)
                                    Spacer()
                                    TextField("한 줄 남기기", text: Binding(
                                        get: { store.memo },
                                        set: { store.send(.memoChanged($0)) }
                                    ))
                                    .font(.appBody)
                                    .multilineTextAlignment(.trailing)
                                }
                                Divider()
                                HStack {
                                    Text("별점").font(.appSection).foregroundStyle(.appInk)
                                    Spacer()
                                    StarRating(rating: store.rating,
                                               onChange: { store.send(.ratingChanged($0)) })
                                }
                            }
                        }

                        PillButton("다이어리에 저장 ♡",
                                   enabled: store.candidates.contains(where: \.isSelected)) {
                            store.send(.saveTapped)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
