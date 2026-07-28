import SwiftUI
import ComposableArchitecture
import Models

public struct CollectionView: View {
    @Bindable var store: StoreOf<CollectionFeature>
    @State private var confirmingDeletion = false
    @State private var pendingSingleDeleteID: UUID?
    @State private var isSpilling = false
    @State private var activeStickerID: UUID?
    @State private var stickerPlacements: [String: StickerBoardPlacement] = [:]
    @AppStorage("collection.freeStickerBoard.v1") private var savedStickerPlacements = ""
    public init(store: StoreOf<CollectionFeature>) { self.store = store }

    public var body: some View {
        ScreenScaffold(title: "컬렉션", onRefresh: refreshBoard) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.appCherry)
                    Text(L10n.format("streak.days", store.streak.current))
                        .font(.appSection)
                        .foregroundStyle(.appInk)
                    if store.streak.best > store.streak.current {
                        Text(L10n.format("streak.best", store.streak.best))
                            .font(.appCaption)
                            .foregroundStyle(.appMuted)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.appCard, in: Capsule())
                .softShadow()

                Spacer()

                headerButton(systemImage: "rectangle.stack.fill", color: .appBlueInk) {
                    store.send(.recapButtonTapped)
                }
                headerButton(systemImage: "rosette", color: .appButterInk) {
                    store.send(.achievementsButtonTapped)
                }
            }

            if store.isEditing {
                selectionToolbar
            }

            if store.cutouts.isEmpty {
                if store.isLoading {
                    KitschLoadingView(
                        "누끼 스티커를 꺼내는 중",
                        messages: ["컬렉션을 가지런히 정리하고 있어요"],
                        compact: true
                    )
                } else {
                    EmptyState(systemImage: "fork.knife", title: "아직 누끼가 없어요",
                               subtitle: "음식 사진을 찍어 첫 누끼를 담아보세요!")
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        KitschSparkle()
                            .fill(Color.appCherry)
                            .frame(width: 12, height: 12)
                        Text("스티커를 잡아 원하는 곳에 붙여보세요")
                            .font(.appCaption)
                            .foregroundStyle(.appPinkInk)
                    }

                    freeStickerBoard
                }

                if store.isEditing {
                    PillButton(
                        store.isDeleting
                            ? "삭제하는 중"
                            : L10n.format(
                                "collection.delete.count",
                                store.selectedCutoutIDs.count
                            ),
                        enabled: !store.selectedCutoutIDs.isEmpty && !store.isDeleting
                    ) {
                        pendingSingleDeleteID = nil
                        confirmingDeletion = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            loadStickerPlacements()
            store.send(.onAppear)
            store.send(.streakOnAppear)
        }
        .onChange(of: store.cutouts.map(\.id)) { _, ids in
            let validKeys = Set(ids.map(\.uuidString))
            let cleaned = stickerPlacements.filter { validKeys.contains($0.key) }
            if cleaned != stickerPlacements {
                stickerPlacements = cleaned
                persistStickerPlacements()
            }
        }
        .sheet(item: $store.scope(state: \.achievements, action: \.achievements)) { achStore in
            AchievementsView(store: achStore)
        }
        .sheet(item: $store.scope(state: \.recap, action: \.recap)) { recapStore in
            RecapView(store: recapStore)
        }
        .confirmationDialog(
            L10n.format(
                "collection.delete.confirm",
                pendingSingleDeleteID == nil ? store.selectedCutoutIDs.count : 1
            ),
            isPresented: $confirmingDeletion,
            titleVisibility: .visible
        ) {
            Button(
                L10n.text(
                    pendingSingleDeleteID == nil ? "선택한 누끼 삭제" : "이 음식 삭제"
                ),
                role: .destructive
            ) {
                if let pendingSingleDeleteID {
                    store.send(.deleteCutoutsConfirmed([pendingSingleDeleteID]))
                    self.pendingSingleDeleteID = nil
                } else {
                    store.send(.deleteSelectedConfirmed)
                }
            }
            Button("취소", role: .cancel) {}
        }
        .alert(
            "삭제하지 못했어요",
            isPresented: Binding(
                get: { store.isDeleteErrorPresented },
                set: { if !$0 { store.send(.dismissDeleteError) } }
            )
        ) {
            Button("확인") { store.send(.dismissDeleteError) }
        } message: {
            Text("잠시 후 다시 시도해주세요.")
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: store.isEditing)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.selectedCutoutIDs)
    }

    private var freeStickerBoard: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let placements = store.cutouts.compactMap {
                stickerPlacements[$0.id.uuidString]
            }
            let height = FreeStickerBoardLayout.boardHeight(
                count: store.cutouts.count,
                width: width,
                placements: placements
            )
            let side = FreeStickerBoardLayout.itemSide(width: width)

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.appCard.opacity(0.42))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                Color.appPinkInk.opacity(0.18),
                                style: StrokeStyle(lineWidth: 1.5, dash: [7, 7])
                            )
                    }

                ForEach(Array(store.cutouts.enumerated()), id: \.element.id) { index, cutout in
                    let point = FreeStickerBoardLayout.point(
                        for: stickerPlacements[cutout.id.uuidString],
                        index: index,
                        width: width,
                        height: height
                    )
                    Button {
                        store.send(
                            store.isEditing
                                ? .selectionToggled(cutout.id)
                                : .cutoutTapped(cutout.id)
                        )
                    } label: {
                        let isFlipped = store.flippedCutoutID == cutout.id
                        ZStack {
                            StickerTile(tint: .rotating(index)) {
                                CutoutImage(fileName: cutout.fileName)
                            }
                            .overlay(alignment: .topTrailing) {
                                if store.isEditing {
                                    Image(systemName:
                                        store.selectedCutoutIDs.contains(cutout.id)
                                            ? "checkmark.circle.fill"
                                            : "circle"
                                    )
                                    .font(.title2.bold())
                                    .foregroundStyle(
                                        store.selectedCutoutIDs.contains(cutout.id)
                                            ? Color.appCherry
                                            : Color.appMuted
                                    )
                                    .padding(7)
                                }
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if let symbol = CutoutDecoration(label: cutout.label).symbol {
                                    KitschIcon(
                                        symbol,
                                        tint: .appPinkInk,
                                        background: .appPink,
                                        size: 34
                                    )
                                    .padding(5)
                                }
                            }
                            .opacity(isFlipped ? 0 : 1)

                            cutoutBack(cutout)
                                .opacity(isFlipped ? 1 : 0)
                                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        }
                        .frame(width: side, height: side)
                        .rotation3DEffect(
                            .degrees(isFlipped ? 180 : 0),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .rotationEffect(.degrees(
                            index.isMultiple(of: 3) ? -2.4 : index.isMultiple(of: 2) ? 2 : 0.5
                        ))
                        .opacity(
                            isSpilling
                                ? 0.05
                                : store.isEditing && !store.selectedCutoutIDs.contains(cutout.id)
                                ? 0.62
                                : 1
                        )
                        .offset(
                            y: isSpilling
                                ? 720 + CGFloat(index / FreeStickerBoardLayout.columns) * 18
                                : 0
                        )
                        .animation(
                            isSpilling
                                ? .easeIn(duration: 0.3).delay(
                                    StickerBoardMotion.spillDelay(index: index)
                                )
                                : .spring(response: 0.48, dampingFraction: 0.72),
                            value: isSpilling
                        )
                    }
                    .buttonStyle(.plain)
                    .position(point)
                    .modifier(
                        FreeStickerDrag(
                            position: point,
                            enabled: !store.isEditing,
                            isActive: activeStickerID == cutout.id,
                            onActiveChange: { active in
                                activeStickerID = active ? cutout.id : nil
                            },
                            onMove: { destination in
                                stickerPlacements[cutout.id.uuidString] =
                                    FreeStickerBoardLayout.placement(
                                        for: destination,
                                        width: width,
                                        height: height
                                    )
                                persistStickerPlacements()
                            }
                        )
                    )
                    .zIndex(activeStickerID == cutout.id ? 100 : Double(index))
                    .contextMenu {
                        Button {
                            store.send(.cutoutTapped(cutout.id))
                        } label: {
                            Label("기록 보기", systemImage: "book.pages")
                        }
                        Button {
                            stickerPlacements.removeValue(forKey: cutout.id.uuidString)
                            persistStickerPlacements()
                        } label: {
                            Label("자리 원래대로", systemImage: "arrow.counterclockwise")
                        }
                        Button {
                            store.send(.beginSelection(cutout.id))
                        } label: {
                            Label("여러 개 선택", systemImage: "checkmark.circle")
                        }
                        Divider()
                        Button(role: .destructive) {
                            pendingSingleDeleteID = cutout.id
                            confirmingDeletion = true
                        } label: {
                            Label("이 음식 삭제", systemImage: "trash")
                        }
                    } preview: {
                        CutoutImage(fileName: cutout.fileName, maxPixelDimension: 320)
                            .frame(width: 190, height: 190)
                            .padding(16)
                            .background(Color.appMilk)
                    }
                }
            }
            .frame(width: width, height: height)
        }
        .frame(height: boardHeightForCurrentWidth)
    }

    private var boardHeightForCurrentWidth: CGFloat {
        // ScreenScaffold uses 18pt horizontal margins on an iPhone-only target.
        let width = max(UIScreen.main.bounds.width - 36, 284)
        return FreeStickerBoardLayout.boardHeight(
            count: store.cutouts.count,
            width: width,
            placements: store.cutouts.compactMap {
                stickerPlacements[$0.id.uuidString]
            }
        )
    }

    private func loadStickerPlacements() {
        guard let data = savedStickerPlacements.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(
                [String: StickerBoardPlacement].self,
                from: data
              ) else { return }
        stickerPlacements = decoded
    }

    private func persistStickerPlacements() {
        guard let data = try? JSONEncoder().encode(stickerPlacements),
              let encoded = String(data: data, encoding: .utf8) else { return }
        savedStickerPlacements = encoded
    }

    @MainActor
    private func refreshBoard() async {
        guard !isSpilling else { return }
        isSpilling = true
        try? await Task.sleep(for: .milliseconds(760))
        await store.send(.onAppear).finish()
        isSpilling = false
    }

    private var selectionToolbar: some View {
        HStack(spacing: 8) {
            if store.isEditing {
                Text(L10n.format("collection.selected.count", store.selectedCutoutIDs.count))
                    .font(.appSection)
                    .foregroundStyle(.appInk)
                Spacer()
                compactTextButton(
                    store.selectedCutoutIDs.count == store.cutouts.count
                        ? "선택 해제"
                        : "전체 선택"
                ) {
                    store.send(.selectAllTapped)
                }
                compactTextButton("완료") {
                    store.send(.editButtonTapped)
                }
            }
        }
    }

    private func compactTextButton(
        _ title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(LocalizedStringKey(title))
            }
        }
        .buttonStyle(
            KitschOutlineButtonStyle(
                color: .appBlueInk,
                verticalPadding: 8
            )
        )
    }

    @ViewBuilder
    private func cutoutBack(_ cutout: CutoutSnapshot) -> some View {
        let info = store.cutoutMealInfo[cutout.id]
        VStack(alignment: .leading, spacing: 6) {
            Text(info?.placeName.isEmpty == false ? info!.placeName : "기록")
                .font(.appSection).foregroundStyle(.appInk).lineLimit(1)
            if let date = info?.dateText, !date.isEmpty {
                Text(date).font(.appCaption).foregroundStyle(.appMuted)
            }
            if let memo = info?.memo, !memo.isEmpty {
                Text("\u{201C}\(memo)\u{201D}").font(.appCaption).foregroundStyle(.appInk).lineLimit(3)
            }
            Spacer(minLength: 0)
            Button {
                store.send(.deleteCutoutsConfirmed([cutout.id]))
            } label: {
                Label("삭제", systemImage: "trash")
                    .font(.appCaption).foregroundStyle(.appPinkInk)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))
        .softShadow()
    }

    private func headerButton(
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(color, in: Circle())
                .overlay {
                    Circle().stroke(Color.appCard, lineWidth: 2.5)
                }
                .softShadow()
        }
        .buttonStyle(KitschPressStyle())
    }
}

private struct FreeStickerDrag: ViewModifier {
    let position: CGPoint
    let enabled: Bool
    let isActive: Bool
    let onActiveChange: (Bool) -> Void
    let onMove: (CGPoint) -> Void

    @GestureState private var translation: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .offset(translation)
            .scaleEffect(isActive ? 1.08 : 1)
            .shadow(
                color: Color.appPinkInk.opacity(isActive ? 0.24 : 0),
                radius: isActive ? 16 : 0,
                y: isActive ? 10 : 0
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isActive)
            .highPriorityGesture(dragGesture, including: enabled ? .all : .none)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .updating($translation) { value, state, _ in
                state = value.translation
            }
            .onChanged { _ in
                if !isActive {
                    onActiveChange(true)
                }
            }
            .onEnded { value in
                onMove(CGPoint(
                    x: position.x + value.translation.width,
                    y: position.y + value.translation.height
                ))
                onActiveChange(false)
            }
    }
}
