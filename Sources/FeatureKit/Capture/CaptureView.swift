import SwiftUI
import PhotosUI
import ComposableArchitecture
import Models

public struct CaptureView: View {
    @Bindable var store: StoreOf<CaptureFeature>
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingPhotoLibrary = false
    @State private var showingCamera = false
    @State private var isLoadingPhotoData = false
    public init(store: StoreOf<CaptureFeature>) { self.store = store }

    private let candidateColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    public var body: some View {
        NavigationStack {
            ScreenScaffold(title: "한 끼 담기", doodle: nil) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("음식 사진 가져오기")
                        .font(.appSection)
                        .foregroundStyle(.appInk)

                    HStack(spacing: 12) {
                        sourceButton(
                            title: "카메라",
                            subtitle: "바로 찍기",
                            systemImage: "camera.fill",
                            color: .appPink,
                            enabled: UIImagePickerController.isSourceTypeAvailable(.camera)
                                && !store.isProcessing
                                && !isLoadingPhotoData
                        ) {
                            showingCamera = true
                        }
                        sourceButton(
                            title: "사진 보관함",
                            subtitle: "최대 10장 선택",
                            systemImage: "photo.on.rectangle.angled",
                            color: .appBlue,
                            enabled: !store.isProcessing && !isLoadingPhotoData
                        ) {
                            showingPhotoLibrary = true
                        }
                    }

                    if store.isProcessing || isLoadingPhotoData {
                        KitschLoadingView(
                            isLoadingPhotoData
                                ? "선택한 사진을 불러오는 중"
                                : processingTitle,
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
                        LazyVGrid(columns: candidateColumns, spacing: 12) {
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
                                tagSection
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
            .photosPicker(
                isPresented: $showingPhotoLibrary,
                selection: $pickerItems,
                maxSelectionCount: 10,
                selectionBehavior: .ordered,
                matching: .images,
                preferredItemEncoding: .automatic
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
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    isLoadingPhotoData = true
                    var photos: [Data] = []
                    photos.reserveCapacity(items.count)
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            photos.append(data)
                        }
                    }
                    pickerItems = []
                    store.send(.photosPicked(photos))
                    isLoadingPhotoData = false
                }
            }
            .alert(
                "저장하지 못했어요",
                isPresented: Binding(
                    get: { store.isSaveErrorPresented },
                    set: { if !$0 { store.send(.dismissSaveError) } }
                )
            ) {
                Button("다시 시도") { store.send(.saveTapped) }
                Button("확인", role: .cancel) { store.send(.dismissSaveError) }
            } message: {
                Text("잠시 후 다시 시도해주세요.")
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: store.candidates)
        .sensoryFeedback(.selection, trigger: store.candidates.map(\.isSelected))
        .task { store.send(.tagsOnAppear) }
        .alert(
            "태그 이름 바꾸기",
            isPresented: Binding(
                get: { store.renamingTag != nil },
                set: { if !$0 { store.send(.renameCancelled) } }
            )
        ) {
            TextField("태그 이름", text: Binding(
                get: { store.renameText },
                set: { store.send(.renameTextChanged($0)) }
            ))
            Button("바꾸기") { store.send(.renameConfirmed) }
            Button("취소", role: .cancel) { store.send(.renameCancelled) }
        }
    }

    /// Pick tags, make new ones, and manage the catalog — all in place, so saving
    /// a meal never sends you off to a separate screen.
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("태그").font(.appSection).foregroundStyle(.appInk)
                Spacer()
                if !store.tags.isEmpty {
                    Text(L10n.format("capture.tags.picked", store.tags.count))
                        .font(.appCaption)
                        .foregroundStyle(.appMuted)
                }
            }

            if store.tagCatalog.isEmpty {
                Text("태그를 만들어 음식을 분류해보세요")
                    .font(.appCaption)
                    .foregroundStyle(.appMuted)
            } else {
                TagFlow(store.tagCatalog) { name in
                    let picked = store.tags.contains { TagName.isSame($0, name) }
                    Button {
                        store.send(.tagToggled(name))
                    } label: {
                        TagChip(name)
                            .opacity(picked ? 1 : 0.45)
                            .overlay {
                                if picked {
                                    Capsule().stroke(Color.appInk.opacity(0.55), lineWidth: 1.5)
                                }
                            }
                    }
                    .buttonStyle(KitschPressStyle())
                    .contextMenu {
                        Button {
                            store.send(.renameTagRequested(name))
                        } label: {
                            Label("이름 바꾸기", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            store.send(.deleteTagRequested(name))
                        } label: {
                            Label("태그 삭제", systemImage: "trash")
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("새 태그 추가", text: Binding(
                    get: { store.newTagText },
                    set: { store.send(.newTagTextChanged($0)) }
                ))
                .font(.appBody)
                .submitLabel(.done)
                .onSubmit { store.send(.newTagSubmitted) }

                Button {
                    store.send(.newTagSubmitted)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.appPinkInk)
                        .frame(width: 30, height: 30)
                        .background(Color.appPink, in: Circle())
                }
                .buttonStyle(KitschPressStyle())
                .disabled(TagName.normalize(store.newTagText) == nil)
                .opacity(TagName.normalize(store.newTagText) == nil ? 0.4 : 1)
            }
        }
    }

    private var processingTitle: String {
        guard store.processingTotal > 1 else {
            return L10n.text("음식 누끼를 만드는 중")
        }
        return L10n.format(
            "capture.processing.progress",
            min(store.processingCompleted + 1, store.processingTotal),
            store.processingTotal
        )
    }

    private func sourceButton(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                KitschIcon(
                    systemImage,
                    tint: .appChocolate,
                    background: color,
                    size: 52
                )
                Text(LocalizedStringKey(title))
                    .font(.appSection)
                    .foregroundStyle(.appInk)
                Text(LocalizedStringKey(subtitle))
                    .font(.appCaption)
                    .foregroundStyle(.appMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(color.opacity(0.9), lineWidth: 2)
            }
            .softShadow()
        }
        .buttonStyle(KitschPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.42)
    }
}
