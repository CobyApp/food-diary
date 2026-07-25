import SwiftUI
import PhotosUI
import ComposableArchitecture

public struct CaptureView: View {
    @Bindable var store: StoreOf<CaptureFeature>
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingSourcePicker = false
    @State private var showingPhotoLibrary = false
    @State private var showingCamera = false
    public init(store: StoreOf<CaptureFeature>) { self.store = store }

    private let candidateColumns = [GridItem(.adaptive(minimum: 90), spacing: 10)]

    public var body: some View {
        NavigationStack {
            ScreenScaffold(title: "한 끼 담기", doodle: nil) {
                VStack(alignment: .leading, spacing: 16) {
                    Button { showingSourcePicker = true } label: {
                        DropZoneCard { Label("음식 사진 고르기", systemImage: "camera") }
                    }
                    .buttonStyle(KitschPressStyle())

                    if store.isProcessing {
                        KitschLoadingView(
                            "음식 누끼를 만드는 중",
                            messages: [
                                "음식만 조심조심 오리는 중",
                                "스티커 테두리를 예쁘게 다듬는 중",
                                "거의 다 됐어요",
                            ],
                            compact: true
                        )
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                    }

                    if !store.candidates.isEmpty {
                        Text("담을 누끼 고르기").font(.appSection).foregroundStyle(.appInk)
                        LazyVGrid(columns: candidateColumns, spacing: 10) {
                            ForEach(Array(store.candidates.enumerated()), id: \.element.id) { index, candidate in
                                Button { store.send(.toggleCandidate(candidate.id)) } label: {
                                    StickerTile(tint: .rotating(index)) {
                                        CutoutImage(
                                            data: candidate.pngData,
                                            cacheKey: candidate.id.uuidString
                                        )
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(candidate.isSelected ? Color.appBlue : Color.appMuted)
                                            .padding(6)
                                    }
                                    .overlay(alignment: .bottomTrailing) {
                                        if let symbol = candidate.decoration.symbol {
                                            KitschIcon(symbol, tint: .appPinkInk, background: .appPink, size: 34)
                                                .padding(5)
                                        }
                                    }
                                    .opacity(candidate.isSelected ? 1 : 0.5)
                                }
                                .buttonStyle(KitschPressStyle())
                                .overlay(alignment: .bottomLeading) {
                                    Button {
                                        store.send(.cycleDecoration(candidate.id))
                                    } label: {
                                        Image(systemName: "paintbrush.pointed.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color.appInk)
                                            .padding(8)
                                            .background(Color.appCard, in: Circle())
                                    }
                                    .buttonStyle(KitschPressStyle())
                                    .padding(5)
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    Button {
                                        store.send(.rotateCandidate(candidate.id))
                                    } label: {
                                        Image(systemName: "rotate.right.fill")
                                            .font(.caption.bold())
                                            .foregroundStyle(Color.appInk)
                                            .padding(8)
                                            .background(Color.appCard, in: Circle())
                                            .rotationEffect(.degrees(candidate.isRotating ? 360 : 0))
                                            .animation(
                                                candidate.isRotating
                                                    ? .linear(duration: 0.7).repeatForever(autoreverses: false)
                                                    : .default,
                                                value: candidate.isRotating
                                            )
                                    }
                                    .buttonStyle(KitschPressStyle())
                                    .disabled(candidate.isRotating)
                                    .accessibilityLabel("오른쪽으로 회전")
                                    .padding(5)
                                }
                            }
                        }

                        SoftCard {
                            VStack(spacing: 12) {
                                Button { store.send(.choosePlaceTapped) } label: {
                                    HStack {
                                        Text("식당").font(.appSection).foregroundStyle(.appInk)
                                        Spacer()
                                        PastelChip(store.chosenPlace?.name ?? L10n.text("선택 안 함"),
                                                   symbol: "mappin.and.ellipse", tone: .blue)
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

                        PillButton(
                            store.isSaving ? "저장하는 중" : "다이어리에 저장",
                            enabled: store.candidates.contains(where: \.isSelected)
                                && !store.candidates.contains(where: \.isRotating)
                                && !store.isSaving
                        ) {
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
            .confirmationDialog("사진 가져오기", isPresented: $showingSourcePicker) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("카메라로 찍기") { showingCamera = true }
                }
                Button("사진 보관함에서 고르기") { showingPhotoLibrary = true }
                Button("취소", role: .cancel) {}
            }
            .photosPicker(
                isPresented: $showingPhotoLibrary,
                selection: $pickerItem,
                matching: .images
            )
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker(
                    onImagePicked: { data in
                        showingCamera = false
                        store.send(.photoPicked(data))
                    },
                    onCancel: { showingCamera = false }
                )
                .ignoresSafeArea()
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
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: store.candidates)
        .sensoryFeedback(.selection, trigger: store.candidates.map(\.isSelected))
    }
}
