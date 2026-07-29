import SwiftUI
import PhotosUI
import ComposableArchitecture
import Models

public struct CaptureView: View {
    @Bindable var store: StoreOf<CaptureFeature>
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingPhotoLibrary = false
    @State private var isLoadingPhotoData = false
    public init(store: StoreOf<CaptureFeature>) { self.store = store }

    private let candidateColumns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    public var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                wizardBar

                // One screen at a time, sliding the way the wizard moves.
                ZStack {
                    switch store.step {
                    case .source: sourceStep
                    case .cutouts: cutoutsStep
                    case .details: detailsStep
                    case .finish: finishStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: store.step)
        .task { store.send(.tagsOnAppear) }
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
        .fullScreenCover(
            isPresented: Binding(
                get: { store.isCameraPresented },
                set: { if !$0 { store.send(.cameraDismissed) } }
            )
        ) {
            CameraPicker(
                onImagePicked: { data in
                    store.send(.cameraDismissed)
                    store.send(.photoPicked(data))
                },
                onCancel: { store.send(.cameraDismissed) }
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
            "카메라를 쓸 수 없어요",
            isPresented: Binding(
                get: { store.isCameraDeniedPresented },
                set: { if !$0 { store.send(.dismissCameraDenied) } }
            )
        ) {
            // iOS only ever asks once, so Settings is the only way back.
            Button("설정 열기") {
                store.send(.dismissCameraDenied)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("취소", role: .cancel) { store.send(.dismissCameraDenied) }
        } message: {
            Text("설정 > Yumkie에서 카메라를 켜주세요. 사진 보관함에서 고르는 것은 그대로 됩니다.")
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

    // MARK: - Chrome

    /// Back, title, and how far along we are.
    private var wizardBar: some View {
        HStack(spacing: 10) {
            if store.step != .source {
                Button { store.send(.previousStep) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.appInk)
                        .frame(width: 36, height: 36)
                        .background(Color.appCard, in: Circle())
                        .softShadow()
                }
                .buttonStyle(KitschPressStyle())
                .transition(.scale.combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text(stepTitle))
                    .font(.appTitle)
                    .foregroundStyle(.appInk)
                Text(L10n.text(stepSubtitle))
                    .font(.appCaption)
                    .foregroundStyle(.appMuted)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 5) {
                ForEach(CaptureFeature.Step.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(
                            step.rawValue <= store.step.rawValue
                                ? Color.appCherry
                                : Color.appChocolate.opacity(0.14)
                        )
                        .frame(width: step == store.step ? 16 : 6, height: 6)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var stepTitle: String {
        switch store.step {
        case .source: return "한 끼 담기"
        case .cutouts: return "누끼 고르기"
        case .details: return "음식 정보"
        case .finish: return "저장하기"
        }
    }

    private var stepSubtitle: String {
        switch store.step {
        case .source: return "사진을 가져오면 음식만 오려줄게요"
        case .cutouts: return "담고 싶은 음식만 골라주세요"
        case .details: return "좌우로 넘기며 음식마다 채워주세요"
        case .finish: return "식당을 고르고 저장해요"
        }
    }

    /// The step's own action, pinned to the bottom so it is always in the same place.
    private func stepFooter<Label: View>(
        enabled: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        VStack(spacing: 0) {
            Divider().opacity(0.5)
            Button(action: action, label: label)
                .buttonStyle(KitschFilledButtonStyle(fullWidth: true, verticalPadding: 15))
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.45)
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 26)
        }
        .background(Color.appMilk.opacity(0.94))
    }

    // MARK: - Step 1: where the photo comes from

    private var sourceStep: some View {
        VStack(spacing: 18) {
            if store.isProcessing || isLoadingPhotoData {
                Spacer(minLength: 0)
                KitschLoadingView(
                    isLoadingPhotoData ? "선택한 사진을 불러오는 중" : processingTitle,
                    messages: [
                        "음식만 조심조심 오리는 중",
                        "스티커 테두리를 예쁘게 다듬는 중",
                        "거의 다 됐어요",
                    ],
                    compact: false
                )
                .padding(.horizontal, 24)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                Spacer(minLength: 0)
            } else {
                // Fills the screen instead of floating in the middle: the two
                // choices share the room, with the how-it-works note under them.
                sourceCard(
                    title: "카메라",
                    subtitle: "지금 먹는 걸 바로 찍기",
                    systemImage: "camera.fill",
                    color: .appPink,
                    enabled: UIImagePickerController.isSourceTypeAvailable(.camera)
                ) {
                    store.send(.cameraTapped)
                }
                sourceCard(
                    title: "사진 보관함",
                    subtitle: "찍어둔 사진에서 최대 10장",
                    systemImage: "photo.on.rectangle.angled",
                    color: .appBlue,
                    enabled: true
                ) {
                    showingPhotoLibrary = true
                }

                howItWorks

                if !store.candidates.isEmpty {
                    Button { store.send(.nextStep) } label: {
                        Label(
                            L10n.format("capture.continue.count", store.candidates.count),
                            systemImage: "arrow.right"
                        )
                    }
                    .buttonStyle(KitschFilledButtonStyle(fullWidth: true, verticalPadding: 14))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 96)   // clears the floating tab bar
    }

    /// Three short lines so the empty first screen still says something useful.
    private var howItWorks: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(Self.howItWorksSteps.enumerated()), id: \.offset) { index, text in
                    HStack(spacing: 10) {
                        Text(verbatim: "\(index + 1)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.appPinkInk)
                            .frame(width: 22, height: 22)
                            .background(Color.appPink, in: Circle())
                        Text(L10n.text(text))
                            .font(.appCaption)
                            .foregroundStyle(.appInk)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static let howItWorksSteps = [
        "사진을 가져오면 음식만 오려내요",
        "담고 싶은 음식만 골라요",
        "음식마다 태그와 별점을 남겨요",
    ]

    /// A wide row rather than a square tile: it reads as a choice, and there is
    /// room to say what each one is for.
    private func sourceCard(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                KitschIcon(systemImage, tint: .appChocolate, background: color, size: 62)
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(title))
                        .font(.appTitle)
                        .foregroundStyle(.appInk)
                    Text(LocalizedStringKey(subtitle))
                        .font(.appCaption)
                        .foregroundStyle(.appMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.appMuted)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(color.opacity(0.9), lineWidth: 2)
            }
            .softShadow()
        }
        .buttonStyle(KitschPressStyle())
        .disabled(!enabled || store.isProcessing || isLoadingPhotoData)
        .opacity(enabled ? 1 : 0.42)
    }

    // MARK: - Step 2: which cutouts to keep

    private var cutoutsStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: candidateColumns, spacing: 12) {
                    ForEach(Array(store.candidates.enumerated()), id: \.element.id) { index, candidate in
                        candidateCard(index: index, candidate: candidate)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            stepFooter(
                enabled: store.candidates.contains(where: \.isSelected)
                    && !store.candidates.contains(where: \.isRotating),
                action: { store.send(.nextStep) }
            ) {
                Label(
                    L10n.format(
                        "capture.next.selected",
                        store.candidates.filter(\.isSelected).count
                    ),
                    systemImage: "arrow.right"
                )
            }
        }
    }

    // MARK: - Step 3: each food's own information

    private var detailsStep: some View {
        VStack(spacing: 0) {
            TabView(
                selection: Binding(
                    get: { store.editingCandidateID ?? store.selectedCandidates.first?.id ?? UUID() },
                    set: { store.send(.editCandidateTapped($0)) }
                )
            ) {
                ForEach(Array(store.selectedCandidates.enumerated()), id: \.element.id) { index, candidate in
                    foodEditorPage(index: index, candidate: candidate)
                        .tag(candidate.id)
                }
            }
            .tabViewStyle(
                .page(indexDisplayMode: store.selectedCandidates.count > 1 ? .always : .never)
            )

            stepFooter(enabled: true, action: { store.send(.nextStep) }) {
                Label("식당 고르기", systemImage: "arrow.right")
            }
        }
    }

    // MARK: - Step 4: restaurant, then save

    private var finishStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    Button { store.send(.choosePlaceTapped) } label: {
                        HStack(spacing: 12) {
                            KitschIcon(
                                "mappin.and.ellipse",
                                tint: .appBlueInk,
                                background: .appBlue,
                                size: 46
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("식당").font(.appCaption).foregroundStyle(.appMuted)
                                Text(store.chosenPlace?.name ?? L10n.text("선택 안 함"))
                                    .font(.appSection)
                                    .foregroundStyle(.appInk)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(.appMuted)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.appCard,
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )
                        .softShadow()
                    }
                    .buttonStyle(KitschPressStyle())

                    // What is about to be saved, so the button is not a leap of faith.
                    SoftCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(
                                L10n.format(
                                    "capture.summary.count",
                                    store.selectedCandidates.count
                                )
                            )
                            .font(.appSection)
                            .foregroundStyle(.appInk)

                            ForEach(store.selectedCandidates) { candidate in
                                HStack(spacing: 10) {
                                    CutoutImage(
                                        data: candidate.pngData,
                                        cacheKey: candidate.id.uuidString
                                    )
                                    .frame(width: 42, height: 42)
                                    if candidate.tags.isEmpty {
                                        Text("태그 없음")
                                            .font(.appCaption)
                                            .foregroundStyle(.appMuted)
                                    } else {
                                        TagChipRow(candidate.tags, limit: 2)
                                    }
                                    Spacer(minLength: 0)
                                    if let rating = candidate.rating {
                                        StarRating(rating: rating)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            stepFooter(
                enabled: !store.selectedCandidates.isEmpty && !store.isSaving,
                action: { store.send(.saveTapped) }
            ) {
                Label(
                    store.isSaving ? "저장하는 중" : "다이어리에 저장",
                    systemImage: "tray.and.arrow.down.fill"
                )
            }
        }
    }

    /// One food's own tags and rating, one card per food, swiped through on a
    /// full screen. A sheet cropped the cutout down to a thumbnail and left the
    /// tag list fighting for the little room underneath.
    @ViewBuilder
    private var foodEditor: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                HStack {
                    Text(
                        L10n.format(
                            "capture.food.position",
                            (store.editingIndex ?? 0) + 1,
                            store.candidates.count
                        )
                    )
                    .font(.appSection)
                    .foregroundStyle(.appMuted)
                    Spacer()
                    Button("완료") { store.send(.dismissCandidateEditor) }
                        .font(.appSection)
                        .foregroundStyle(.appPinkInk)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                TabView(
                    selection: Binding(
                        get: { store.editingCandidateID ?? store.candidates.first?.id ?? UUID() },
                        set: { store.send(.editCandidateTapped($0)) }
                    )
                ) {
                    ForEach(Array(store.candidates.enumerated()), id: \.element.id) { index, candidate in
                        foodEditorPage(index: index, candidate: candidate)
                            .tag(candidate.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: store.candidates.count > 1 ? .always : .never))
            }
        }
    }

    private func foodEditorPage(
        index: Int,
        candidate: CaptureFeature.CutoutCandidate
    ) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                // Big and centred: this is the thing being described.
                StickerTile(tint: .rotating(index)) {
                    CutoutImage(data: candidate.pngData, cacheKey: candidate.id.uuidString)
                }
                .frame(maxWidth: 280)
                .frame(maxWidth: .infinity)

                SoftCard { tagSection }

                SoftCard {
                    HStack {
                        Text("별점").font(.appSection).foregroundStyle(.appInk)
                        Spacer()
                        StarRating(
                            rating: candidate.rating,
                            onChange: { store.send(.ratingChanged($0)) }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private func candidateCard(index: Int, candidate: CaptureFeature.CutoutCandidate) -> some View {
        VStack(spacing: 7) {
            Button { store.send(.toggleCandidate(candidate.id)) } label: {
                StickerTile(tint: .rotating(index)) {
                    CutoutImage(data: candidate.pngData, cacheKey: candidate.id.uuidString)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(candidate.isSelected ? Color.appBlue : Color.appMuted)
                        .padding(6)
                }
                .overlay(alignment: .bottomLeading) { decorationButton(candidate) }
                .overlay(alignment: .bottomTrailing) { rotateButton(candidate) }
                .opacity(candidate.isSelected ? 1 : 0.5)
            }
            .buttonStyle(KitschPressStyle())

            Button { store.send(.editCandidateTapped(candidate.id)) } label: {
                HStack(spacing: 5) {
                    Image(systemName: "tag.fill").font(.system(size: 10, weight: .black))
                    if candidate.tags.isEmpty, candidate.rating == nil {
                        Text("정보 넣기")
                    } else {
                        Text(candidate.tags.first ?? L10n.text("별점만"))
                            .lineLimit(1)
                        if candidate.tags.count > 1 {
                            Text(verbatim: "+\(candidate.tags.count - 1)")
                        }
                    }
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.appBlueInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appBlue.opacity(0.5), in: Capsule())
            }
            .buttonStyle(KitschPressStyle())
        }
    }

    private func decorationButton(_ candidate: CaptureFeature.CutoutCandidate) -> some View {
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

    private func rotateButton(_ candidate: CaptureFeature.CutoutCandidate) -> some View {
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

    /// Pick tags, make new ones, and manage the catalog — all in place, so saving
    /// a meal never sends you off to a separate screen.
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("태그").font(.appSection).foregroundStyle(.appInk)
                Spacer()
                let picked = store.editingCandidate?.tags ?? []
                if !picked.isEmpty {
                    Text(L10n.format("capture.tags.picked", picked.count))
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
                    let isOn = (store.editingCandidate?.tags ?? []).contains { TagName.isSame($0, name) }
                    Button {
                        store.send(.tagToggled(name))
                    } label: {
                        TagChip(name)
                            .opacity(isOn ? 1 : 0.45)
                            .overlay {
                                if isOn {
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
