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
    @State private var showingRecapDatePicker = false
    @State private var showingBoardStylePicker = false
    @State private var showingCutoutDrawer = false
    @State private var showingRecapOptions = false
    @State private var draftRecapStartDate = Date()
    @State private var draftRecapEndDate = Date()
    @State private var transformPreview: StickerTransformPreview?
    /// The sticker showing its corner handle. Adjusting is deliberate rather than
    /// something a stray pinch triggers.
    @State private var transformingStickerID: UUID?
    @State private var motion = ParallaxMotion()
    /// Measured height of the floating chrome, used as the board's top inset.
    @State private var controlsHeight: CGFloat = 0
    /// Set only after the tilt has been held, so a passing wobble doesn't flash
    /// every place name on the board.
    @State private var revealedSide: StickerBoardMotion.BoardSide?
    @State private var offBoardIDs: Set<String> = []
    @AppStorage("collection.freeStickerBoard.v1") private var savedStickerPlacements = ""
    /// Cutouts taken off the board. Absence means on the board, so a newly saved
    /// meal lands on it by itself — the way a new file appears on a desktop.
    @AppStorage("collection.stickerBoardOffBoard.v1") private var savedOffBoardIDs = ""
    @AppStorage("collection.stickerBoardTheme.v1")
    private var selectedThemeRaw = StickerBoardTheme.strawberryCheck.rawValue
    public init(store: StoreOf<CollectionFeature>) { self.store = store }

    private var selectedTheme: StickerBoardTheme {
        StickerBoardTheme(rawValue: selectedThemeRaw) ?? .strawberryCheck
    }

    /// What is actually out on the board.
    private var boardCutouts: [FoodEntrySnapshot] {
        store.cutouts.filter { !offBoardIDs.contains($0.id.uuidString) }
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // The whole screen is the board: the chosen style paints the page
            // itself rather than filling a framed card sitting inside it.
            StickerBoardThemeBackground(theme: selectedTheme)
                .ignoresSafeArea()

            canvas

            floatingControls

        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            loadStickerPlacements()
            loadOffBoardIDs()
            store.send(.onAppear)
            store.send(.streakOnAppear)
            motion.start()
        }
        .onDisappear { motion.stop() }
        .task(id: tiltedSide) { await holdTiltToReveal() }
        .onChange(of: store.cutouts.map(\.id)) { _, ids in
            // A deleted food leaves both the board and the drawer.
            let validKeys = Set(ids.map(\.uuidString))
            let cleaned = stickerPlacements.filter { validKeys.contains($0.key) }
            if cleaned != stickerPlacements {
                stickerPlacements = cleaned
                persistStickerPlacements()
            }
            let keptOffBoard = offBoardIDs.intersection(validKeys)
            if keptOffBoard != offBoardIDs {
                offBoardIDs = keptOffBoard
                persistOffBoardIDs()
            }
        }
        .sheet(item: $store.scope(state: \.achievements, action: \.achievements)) { achStore in
            AchievementsView(store: achStore)
        }
        .sheet(item: $store.scope(state: \.recap, action: \.recap)) { recapStore in
            RecapView(store: recapStore)
        }
        .sheet(isPresented: $showingRecapDatePicker) {
            RecapDateRangePicker(
                startDate: $draftRecapStartDate,
                endDate: $draftRecapEndDate,
                onApply: {
                    store.send(.recapDateRangeChanged(
                        start: draftRecapStartDate,
                        end: draftRecapEndDate
                    ))
                    showingRecapDatePicker = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingCutoutDrawer) {
            NavigationStack {
                cutoutDrawer
                    .background(PaperBackground())
                    .navigationTitle("누끼 서랍")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("닫기") { showingCutoutDrawer = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appMilk)
        }
        .sheet(isPresented: $showingRecapOptions) {
            NavigationStack {
                VStack(spacing: 14) {
                    recapPeriodCard
                    Spacer(minLength: 0)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .top)
                .background(PaperBackground())
                .navigationTitle("리캡 만들기")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("닫기") { showingRecapOptions = false }
                    }
                }
            }
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appMilk)
        }
        .sheet(isPresented: $showingBoardStylePicker) {
            NavigationStack {
                ScrollView {
                    boardStylePicker
                        .padding(20)
                }
                .scrollIndicators(.hidden)
                .background(PaperBackground())
                .navigationTitle("보드 꾸미기")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("닫기") {
                            showingBoardStylePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appMilk)
        }
        .sheet(
            isPresented: Binding(
                get: { store.selectedCutoutID != nil },
                set: { if !$0 { store.send(.dismissCutoutDetail) } }
            )
        ) {
            if let selectedCutoutID = store.selectedCutoutID,
               let cutout = store.cutouts.first(where: { $0.id == selectedCutoutID }) {
                StickerDetailSheet(
                    cutout: cutout,
                    info: store.cutoutMealInfo[selectedCutoutID],
                    theme: selectedTheme,
                    onClose: { store.send(.dismissCutoutDetail) }
                )
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
                .presentationBackground(Color.appMilk)
                .presentationContentInteraction(.scrolls)
            }
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

    private var recapPeriodCard: some View {
        HStack(spacing: 10) {
            Button {
                draftRecapStartDate = store.recapStartDate
                draftRecapEndDate = store.recapEndDate
                showingRecapDatePicker = true
            } label: {
                HStack(spacing: 9) {
                    KitschIcon(
                        "calendar",
                        tint: .appPinkInk,
                        background: .appPink,
                        size: 40
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("공유 기간")
                            .font(.appCaption)
                            .foregroundStyle(.appMuted)
                        Text(store.recapRangeText)
                            .font(.appSection)
                            .foregroundStyle(.appInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }
            }
            .buttonStyle(KitschPressStyle())

            Spacer(minLength: 4)

            Button {
                showingRecapOptions = false
                store.send(.recapButtonTapped)
            } label: {
                Label("리캡 만들기", systemImage: "square.and.arrow.up")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(
                KitschFilledButtonStyle(
                    fullWidth: false,
                    verticalPadding: 10
                )
            )
        }
        .padding(12)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.appPinkInk.opacity(0.25), lineWidth: 1.5)
        }
        .softShadow()
    }

    /// The scrolling canvas. Full-bleed, and tall enough to fill the screen even
    /// when there is almost nothing on it.
    private var canvas: some View {
        ScrollView {
            if boardCutouts.isEmpty {
                emptyBoard
                    .padding(.horizontal, 18)
                    .padding(.top, controlsHeight + 28)
                    .padding(.bottom, 96)
            } else {
                VStack(spacing: 14) {
                    freeStickerBoard

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
                        .padding(.horizontal, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 96)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await refreshBoard() }
    }

    /// Every cutout ever saved. The board shows a chosen few; this is the drawer
    /// they come out of, so taking one off the board never loses it.
    private var cutoutDrawer: some View {
        ScrollView {
            if store.cutouts.isEmpty {
                EmptyState(systemImage: "fork.knife", title: "아직 누끼가 없어요",
                           subtitle: "음식 사진을 찍어 첫 누끼를 담아보세요!")
                    .padding(.top, 30)
                    .padding(.horizontal, 18)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.format("drawer.count", boardCutouts.count, store.cutouts.count))
                        .font(.appCaption)
                        .foregroundStyle(.appMuted)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 96), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(Array(store.cutouts.enumerated()), id: \.element.id) { index, cutout in
                            let isOut = !offBoardIDs.contains(cutout.id.uuidString)
                            Button {
                                if isOut {
                                    removeFromBoard(cutout)
                                } else {
                                    addToBoard(cutout)
                                }
                            } label: {
                                StickerTile(tint: .rotating(index)) {
                                    CutoutImage(fileName: cutout.fileName)
                                }
                                .aspectRatio(1, contentMode: .fit)
                                .opacity(isOut ? 1 : 0.45)
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: isOut ? "checkmark.circle.fill" : "plus.circle")
                                        .font(.title3.bold())
                                        .foregroundStyle(isOut ? Color.appCherry : Color.appMuted)
                                        .padding(6)
                                }
                            }
                            .buttonStyle(KitschPressStyle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    pendingSingleDeleteID = cutout.id
                                    showingCutoutDrawer = false
                                    confirmingDeletion = true
                                } label: {
                                    Label("이 음식 삭제", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .scrollIndicators(.hidden)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: offBoardIDs)
    }

    @ViewBuilder
    private var emptyBoard: some View {
        if store.isLoading {
            KitschLoadingView(
                "누끼 스티커를 꺼내는 중",
                messages: ["컬렉션을 가지런히 정리하고 있어요"],
                compact: true
            )
        } else if store.cutouts.isEmpty {
            EmptyState(systemImage: "fork.knife", title: "아직 누끼가 없어요",
                       subtitle: "음식 사진을 찍어 첫 누끼를 담아보세요!")
        } else {
            // Food exists, it is just all in the drawer.
            EmptyState(systemImage: "square.grid.2x2", title: "보드가 비어 있어요",
                       subtitle: "서랍에서 누끼를 꺼내 보드에 올려보세요!")
        }
    }

    /// Chrome that stays put while the canvas scrolls under it. Its height feeds
    /// the board's top inset so a sticker never spawns hidden behind it.
    private var floatingControls: some View {
        VStack(spacing: 10) {
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

                headerButton(systemImage: "square.grid.2x2.fill", color: .appBlueInk) {
                    showingCutoutDrawer = true
                }
                .accessibilityLabel(Text("누끼 서랍"))

                headerButton(systemImage: "paintpalette.fill", color: .appPinkInk) {
                    showingBoardStylePicker = true
                }
                .accessibilityLabel(Text("보드 꾸미기"))

                headerButton(systemImage: "rosette", color: .appButterInk) {
                    store.send(.achievementsButtonTapped)
                }

                headerButton(systemImage: "square.and.arrow.up", color: .appChocolate) {
                    showingRecapOptions = true
                }
                .accessibilityLabel(Text("리캡 만들기"))
            }

            if store.isEditing {
                selectionToolbar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.appCard.opacity(0.95), in: Capsule())
                    .softShadow()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            controlsHeight = height
        }
    }

    private var freeStickerBoard: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let cutouts = boardCutouts
            let placements = cutouts.compactMap {
                stickerPlacements[$0.id.uuidString]
            }
            let height = FreeStickerBoardLayout.boardHeight(
                count: cutouts.count,
                width: width,
                placements: placements,
                topInset: controlsHeight,
                minimum: canvasMinimumHeight
            )
            let side = FreeStickerBoardLayout.itemSide(width: width)

            ZStack {
                ForEach(Array(cutouts.enumerated()), id: \.element.id) { index, cutout in
                    let savedPlacement = stickerPlacements[cutout.id.uuidString]
                    let point = FreeStickerBoardLayout.point(
                        for: savedPlacement,
                        index: index,
                        width: width,
                        height: height,
                        topInset: controlsHeight
                    )
                    let isRevealed = StickerBoardMotion.isRevealed(
                        xFraction: width > 0 ? Double(point.x / width) : 0.5,
                        side: revealedSide
                    )
                    // A sticker under a finger, or mid-spill, already has motion
                    // of its own — leaning it as well just fights that.
                    let isBusy = activeStickerID == cutout.id || isSpilling
                    let lean = isBusy
                        ? CGSize.zero
                        : StickerBoardMotion.lean(
                            index: index,
                            tiltX: motion.tiltX,
                            tiltY: motion.tiltY
                        )
                    let leanRotation = isBusy
                        ? 0
                        : StickerBoardMotion.leanRotation(index: index, tiltX: motion.tiltX)
                    Button {
                        store.send(
                            store.isEditing
                                ? .selectionToggled(cutout.id)
                                : .cutoutTapped(cutout.id)
                        )
                    } label: {
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
                        .overlay(alignment: .bottomLeading) {
                            if let rating = store.cutoutMealInfo[cutout.id]?.rating {
                                StickerRatingBadge(rating: rating)
                                    .padding(6)
                            }
                        }
                        .frame(width: side, height: side)
                        .overlay(alignment: .top) {
                            revealedPlaceChip(for: cutout, visible: isRevealed)
                        }
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
                        // Tilt response goes on last and unanimated: the sensor
                        // stream is already smoothed, and a spring here would
                        // only add lag between the device and the board.
                        .scaleEffect(isRevealed ? 1.06 : 1)
                        .rotationEffect(.degrees(leanRotation))
                        .offset(x: lean.width, y: lean.height)
                    }
                    .buttonStyle(.plain)
                    .position(point)
                    .modifier(
                        FreeStickerDrag(
                            position: point,
                            baseScale: savedPlacement?.displayScale ?? 1,
                            baseRotation: savedPlacement?.rotation
                                ?? FreeStickerBoardLayout.defaultRotation(index: index),
                            enabled: !store.isEditing,
                            isActive: activeStickerID == cutout.id,
                            onActiveChange: { active in
                                activeStickerID = active ? cutout.id : nil
                                if !active, transformPreview?.id == cutout.id {
                                    transformPreview = nil
                                }
                            },
                            onPreview: { scale, rotation, isScaling, isRotating in
                                transformPreview = StickerTransformPreview(
                                    id: cutout.id,
                                    scale: scale,
                                    rotation: rotation,
                                    isScaling: isScaling,
                                    isRotating: isRotating
                                )
                            },
                            onMove: { destination in
                                let current = stickerPlacements[cutout.id.uuidString]
                                stickerPlacements[cutout.id.uuidString] =
                                    FreeStickerBoardLayout.placement(
                                        for: destination,
                                        width: width,
                                        height: height,
                                        preserving: current
                                    )
                                persistStickerPlacements()
                            },
                            onTransform: { scale, rotation in
                                let key = cutout.id.uuidString
                                var updated = stickerPlacements[key]
                                    ?? FreeStickerBoardLayout.placement(
                                        for: point,
                                        width: width,
                                        height: height
                                    )
                                if let scale {
                                    updated.scale = FreeStickerBoardLayout.clampedScale(scale)
                                }
                                if let rotation {
                                    updated.rotation =
                                        FreeStickerBoardLayout.normalizedRotation(rotation)
                                }
                                let clampedPoint = FreeStickerBoardLayout.clamped(
                                    CGPoint(
                                        x: width * CGFloat(updated.xFraction),
                                        y: CGFloat(updated.y)
                                    ),
                                    width: width,
                                    height: height,
                                    scale: updated.displayScale,
                                    rotationDegrees: updated.rotation ?? 0
                                )
                                updated.xFraction = Double(clampedPoint.x / width)
                                updated.y = Double(clampedPoint.y)
                                stickerPlacements[key] = updated
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
                            transformingStickerID = cutout.id
                        } label: {
                            Label("크기·회전 조절", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                        Button {
                            removeFromBoard(cutout)
                        } label: {
                            Label("보드에서 내리기", systemImage: "tray.and.arrow.down")
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

                if let id = transformingStickerID,
                   let index = cutouts.firstIndex(where: { $0.id == id }) {
                    let placement = stickerPlacements[id.uuidString]
                    let center = FreeStickerBoardLayout.point(
                        for: placement,
                        index: index,
                        width: width,
                        height: height,
                        topInset: controlsHeight
                    )
                    let scale = placement?.displayScale ?? 1
                    let rotation = placement?.rotation
                        ?? FreeStickerBoardLayout.defaultRotation(index: index)

                    StickerTransformHandle(
                        center: center,
                        side: side,
                        scale: scale,
                        rotationDegrees: rotation,
                        onDrag: { location in
                            applyHandleTransform(
                                for: id,
                                handle: location,
                                center: center,
                                side: side,
                                width: width,
                                height: height
                            )
                        },
                        onDone: { transformingStickerID = nil }
                    )
                    .zIndex(2_000)

                    if let transformPreview, transformPreview.id == id {
                        StickerTransformBadge(preview: transformPreview)
                            .position(
                                x: center.x,
                                y: max(14, center.y - side * scale / 2 - 16)
                            )
                            .zIndex(2_001)
                    }
                }
            }
            .frame(width: width, height: height)
            .coordinateSpace(.named("board"))
        }
        .frame(height: boardHeightForCurrentWidth)
    }

    private var boardStylePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("보드 꾸미기")
                    .font(.appSection)
                    .foregroundStyle(.appInk)
                Spacer()
                Text("선택한 꾸미기는 인스타 카드에도 적용돼요")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.appMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Text("배경 무늬")
                .font(.appCaption)
                .foregroundStyle(.appPinkInk)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(StickerBoardTheme.allCases) { theme in
                        let selected = selectedTheme == theme
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                selectedThemeRaw = theme.rawValue
                            }
                        } label: {
                            VStack(spacing: 6) {
                                StickerBoardThemeBackground(theme: theme)
                                    .frame(width: 74, height: 52)
                                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .stroke(
                                                selected ? theme.accent : Color.appCard,
                                                lineWidth: selected ? 3 : 2
                                            )
                                    }
                                    .overlay(alignment: .bottomTrailing) {
                                        if selected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .black))
                                                .foregroundStyle(.white)
                                                .frame(width: 20, height: 20)
                                                .background(theme.accent, in: Circle())
                                                .overlay(Circle().stroke(Color.appCard, lineWidth: 2))
                                                .offset(x: 4, y: 4)
                                        }
                                    }

                                Text(L10n.text(theme.titleKey))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(selected ? theme.accent : Color.appInk)
                                    .lineLimit(1)
                            }
                            .padding(7)
                            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(
                                        selected
                                            ? theme.accent.opacity(0.65)
                                            : Color.appChocolate.opacity(0.10),
                                        lineWidth: selected ? 2 : 1
                                    )
                            }
                        }
                        .buttonStyle(KitschPressStyle())
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 5)
            }
            .scrollIndicators(.hidden)
        }
        .padding(14)
        .background(Color.appCard.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.appChocolate.opacity(0.08), lineWidth: 1)
        }
    }

    /// A canvas shorter than the screen would leave the styled page cut off part
    /// way down, so it never goes below one screenful.
    private var canvasMinimumHeight: CGFloat {
        max(UIScreen.main.bounds.height, FreeStickerBoardLayout.minimumHeight)
    }

    private var boardHeightForCurrentWidth: CGFloat {
        // Full-bleed now: the canvas runs edge to edge.
        let width = max(UIScreen.main.bounds.width, 284)
        let cutouts = boardCutouts
        return FreeStickerBoardLayout.boardHeight(
            count: cutouts.count,
            width: width,
            placements: cutouts.compactMap {
                stickerPlacements[$0.id.uuidString]
            },
            topInset: controlsHeight,
            minimum: canvasMinimumHeight
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

    private func loadOffBoardIDs() {
        guard let data = savedOffBoardIDs.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data)
        else { return }
        offBoardIDs = decoded
    }

    private func persistOffBoardIDs() {
        guard let data = try? JSONEncoder().encode(offBoardIDs),
              let encoded = String(data: data, encoding: .utf8) else { return }
        savedOffBoardIDs = encoded
    }

    /// Reads a corner-handle drag back into the sticker's saved scale and angle.
    private func applyHandleTransform(
        for id: UUID,
        handle: CGPoint,
        center: CGPoint,
        side: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) {
        let key = id.uuidString
        let result = FreeStickerBoardLayout.handleTransform(
            handle: handle,
            center: center,
            side: side
        )
        var updated = stickerPlacements[key] ?? FreeStickerBoardLayout.placement(
            for: center,
            width: width,
            height: height
        )
        updated.scale = result.scale
        updated.rotation = result.rotation
        // A sticker grown near an edge has to stay reachable.
        let clampedPoint = FreeStickerBoardLayout.clamped(
            CGPoint(x: width * CGFloat(updated.xFraction), y: CGFloat(updated.y)),
            width: width,
            height: height,
            scale: updated.displayScale,
            rotationDegrees: updated.rotation ?? 0
        )
        updated.xFraction = Double(clampedPoint.x / width)
        updated.y = Double(clampedPoint.y)
        stickerPlacements[key] = updated
        transformPreview = StickerTransformPreview(
            id: id,
            scale: updated.displayScale,
            rotation: updated.rotation ?? 0,
            isScaling: true,
            isRotating: true
        )
    }

    /// Takes a sticker off the board. The food itself stays in the drawer.
    private func removeFromBoard(_ cutout: FoodEntrySnapshot) {
        offBoardIDs.insert(cutout.id.uuidString)
        stickerPlacements.removeValue(forKey: cutout.id.uuidString)
        persistOffBoardIDs()
        persistStickerPlacements()
    }

    /// Puts a sticker back out, in the first slot nothing else is sitting in.
    private func addToBoard(_ cutout: FoodEntrySnapshot) {
        let width = max(UIScreen.main.bounds.width, 284)
        let height = boardHeightForCurrentWidth
        let occupied = boardCutouts.map {
            FreeStickerBoardLayout.point(
                for: stickerPlacements[$0.id.uuidString],
                index: 0,
                width: width,
                height: height,
                topInset: controlsHeight
            )
        }
        let slot = FreeStickerBoardLayout.firstFreeSlot(
            occupied: occupied,
            width: width,
            height: height,
            topInset: controlsHeight
        )
        offBoardIDs.remove(cutout.id.uuidString)
        stickerPlacements[cutout.id.uuidString] = FreeStickerBoardLayout.placement(
            for: slot,
            width: width,
            height: height
        )
        persistOffBoardIDs()
        persistStickerPlacements()
    }

    private func persistStickerPlacements() {
        guard let data = try? JSONEncoder().encode(stickerPlacements),
              let encoded = String(data: data, encoding: .utf8) else { return }
        savedStickerPlacements = encoded
    }

    /// Which half the device leans toward right now, before the hold debounce.
    private var tiltedSide: StickerBoardMotion.BoardSide? {
        StickerBoardMotion.revealedSide(tiltX: motion.tiltX, threshold: 0.55)
    }

    /// Tilt and hold to read the place names on that half of the board. Driven by
    /// `.task(id:)`, so changing or releasing the tilt cancels a pending reveal.
    private func holdTiltToReveal() async {
        guard let tiltedSide else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { revealedSide = nil }
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(300))
        } catch {
            return
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
            revealedSide = tiltedSide
        }
    }

    @ViewBuilder
    private func revealedPlaceChip(for cutout: FoodEntrySnapshot, visible: Bool) -> some View {
        let placeName = store.cutoutMealInfo[cutout.id]?.placeName ?? ""
        if visible, !placeName.isEmpty {
            Text(placeName)
                .font(.appCaption)
                .foregroundStyle(.appInk)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.appCard.opacity(0.95), in: Capsule())
                .softShadow()
                .fixedSize()
                .offset(y: -11)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
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

private struct RecapDateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    presetButton("오늘") {
                        let today = calendar.startOfDay(for: Date())
                        startDate = today
                        endDate = today
                    }
                    presetButton("최근 7일") {
                        let today = calendar.startOfDay(for: Date())
                        startDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
                        endDate = today
                    }
                    presetButton("이번 달") {
                        let today = calendar.startOfDay(for: Date())
                        startDate = calendar.dateInterval(of: .month, for: today)?.start ?? today
                        endDate = today
                    }
                }

                VStack(spacing: 12) {
                    dateRow(
                        "시작일",
                        selection: $startDate,
                        range: Date.distantPast...endDate
                    )
                    dateRow("종료일", selection: $endDate, range: startDate...Date())
                }
                .padding(16)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.appPinkInk.opacity(0.22), lineWidth: 1.5)
                }

                PillButton("이 기간으로 만들기", action: onApply)
                Spacer(minLength: 0)
            }
            .padding(20)
            .background(PaperBackground())
            .navigationTitle("기간 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func presetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
        }
        .buttonStyle(
            KitschOutlineButtonStyle(
                color: .appPinkInk,
                fullWidth: true,
                verticalPadding: 9
            )
        )
    }

    private func dateRow(
        _ title: String,
        selection: Binding<Date>,
        range: ClosedRange<Date>
    ) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
                .font(.appSection)
                .foregroundStyle(.appInk)
            Spacer()
            DatePicker(
                LocalizedStringKey(title),
                selection: selection,
                in: range,
                displayedComponents: .date
            )
            .labelsHidden()
            .tint(.appCherry)
        }
    }
}

private struct StickerRatingBadge: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
            Text("\(rating)")
        }
        .font(.system(size: 11, weight: .black, design: .rounded))
        .foregroundStyle(.appChocolate)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.appButter, in: Capsule())
        .overlay(Capsule().stroke(Color.appCard, lineWidth: 2))
        .softShadow()
    }
}

private struct StickerDetailSheet: View {
    let cutout: FoodEntrySnapshot
    let info: CutoutMealInfo?
    let theme: StickerBoardTheme
    let onClose: () -> Void

    private var tags: [String] {
        info?.tags ?? []
    }

    var body: some View {
        ZStack {
            PaperBackground()

            VStack {
                ZStack {
                    Circle()
                        .fill(theme.secondary.opacity(0.34))
                        .frame(width: 210, height: 210)
                        .offset(x: 145, y: -92)
                    Circle()
                        .fill(theme.accent.opacity(0.08))
                        .frame(width: 150, height: 150)
                        .offset(x: -145, y: -38)
                }
                .frame(height: 130)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("한 끼 기록")
                                .font(.appTitle)
                                .foregroundStyle(.appInk)
                            Text(info?.dateText ?? "")
                                .font(.appCaption)
                                .foregroundStyle(.appMuted)
                        }
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(theme.accent)
                                .frame(width: 34, height: 34)
                                .background(Color.appCard, in: Circle())
                                .overlay(Circle().stroke(theme.accent.opacity(0.4), lineWidth: 2))
                        }
                        .buttonStyle(KitschPressStyle())
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .fill(Color.appCard.opacity(0.90))
                        Circle()
                            .fill(theme.secondary.opacity(0.34))
                            .frame(width: 210, height: 210)
                        StickerTile(tint: .plain) {
                            CutoutImage(fileName: cutout.fileName, maxPixelDimension: 520)
                        }
                        .frame(width: 218, height: 218)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 244)
                    .overlay {
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .stroke(
                                theme.accent.opacity(0.30),
                                style: StrokeStyle(lineWidth: 1.5, dash: [7, 6])
                            )
                    }
                    .softShadow()

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            detailChips
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            detailChips
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text("별점")
                                .font(.appSection)
                                .foregroundStyle(.appInk)
                            Spacer()
                            if let rating = info?.rating {
                                Text("\(rating)/5")
                                    .font(.appCaption)
                                    .foregroundStyle(.appButterInk)
                                    .monospacedDigit()
                            } else {
                                Text("아직 별점이 없어요")
                                    .font(.appCaption)
                                    .foregroundStyle(.appMuted)
                            }
                        }
                        StarRating(rating: info?.rating)
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.appButterInk.opacity(0.22), lineWidth: 1.5)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("태그")
                            .font(.appSection)
                            .foregroundStyle(.appInk)
                        if tags.isEmpty {
                            Text("아직 태그가 없어요")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.appMuted)
                                .padding(.vertical, 4)
                        } else {
                            TagFlow(tags) { TagChip($0) }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appCard.opacity(0.96), in: RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(theme.accent.opacity(0.28), lineWidth: 1.5)
                    }

                    PillButton("닫기", action: onClose)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var detailChips: some View {
        if let placeName = info?.placeName, !placeName.isEmpty {
            PastelChip(placeName, symbol: "mappin", tone: .pink)
        }
        if !cutout.label.orEmpty.isEmpty {
            PastelChip(cutout.label.orEmpty, tone: .blue)
        }
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}

private struct StickerTransformPreview: Equatable {
    let id: UUID
    let scale: CGFloat
    let rotation: Double
    let isScaling: Bool
    let isRotating: Bool
}

private struct FreeStickerDrag: ViewModifier {
    let position: CGPoint
    let baseScale: CGFloat
    let baseRotation: Double
    let enabled: Bool
    let isActive: Bool
    let onActiveChange: (Bool) -> Void
    let onPreview: (CGFloat, Double, Bool, Bool) -> Void
    let onMove: (CGPoint) -> Void
    let onTransform: (Double?, Double?) -> Void

    @GestureState private var translation: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var gestureRotation: Angle = .zero
    @GestureState private var isDragging = false
    @GestureState private var isMagnifying = false
    @GestureState private var isRotating = false
    /// Latched for the whole gesture, because a two-finger pinch also feeds the
    /// drag gesture: without this the sticker slides away while being resized,
    /// and the stray translation is then saved as its new position.
    @State private var isTransforming = false

    private var isInteracting: Bool {
        isDragging || isMagnifying || isRotating
    }

    private var liveScale: CGFloat {
        CGFloat(
            FreeStickerBoardLayout.clampedScale(
                Double(baseScale * magnification)
            )
        )
    }

    private var liveRotation: Double {
        FreeStickerBoardLayout.normalizedRotation(
            baseRotation + gestureRotation.degrees
        )
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isInteracting || isActive {
                    StickerSelectionBoundary()
                        .transition(.opacity)
                }
            }
            .scaleEffect(
                liveScale * ((isInteracting || isActive) ? 1.025 : 1)
            )
            .rotationEffect(.degrees(liveRotation))
            .shadow(
                color: Color.appPinkInk.opacity((isInteracting || isActive) ? 0.24 : 0),
                radius: (isInteracting || isActive) ? 16 : 0,
                y: (isInteracting || isActive) ? 10 : 0
            )
            // Translation comes last so a scaled sticker still follows the
            // finger one-for-one instead of multiplying the drag distance.
            .offset(isTransforming ? .zero : translation)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isActive)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isInteracting)
            .highPriorityGesture(dragGesture, including: enabled ? .all : .none)
            .simultaneousGesture(magnifyGesture, including: enabled ? .all : .none)
            .simultaneousGesture(rotationGesture, including: enabled ? .all : .none)
            .onChange(of: isInteracting) { _, active in
                onActiveChange(active)
                if active {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } else {
                    // Cleared only once every finger is up, so a pinch that ends
                    // just before the drag does cannot let the move through.
                    isTransforming = false
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .updating($translation) { value, state, _ in
                state = value.translation
            }
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onEnded { value in
                guard !isTransforming else { return }
                onMove(CGPoint(
                    x: position.x + value.translation.width,
                    y: position.y + value.translation.height
                ))
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .updating($magnification) { value, state, _ in
                state = value
            }
            .updating($isMagnifying) { _, state, _ in
                state = true
            }
            .onChanged { value in
                isTransforming = true
                onPreview(
                    CGFloat(
                        FreeStickerBoardLayout.clampedScale(
                            Double(baseScale * value)
                        )
                    ),
                    liveRotation,
                    true,
                    isRotating
                )
            }
            .onEnded { value in
                let rawScale = Double(baseScale * value)
                let snappedScale = FreeStickerBoardLayout.snappedScale(rawScale)
                onTransform(snappedScale, nil)
                if abs(snappedScale - rawScale) > 0.001 {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .updating($gestureRotation) { value, state, _ in
                state = value
            }
            .updating($isRotating) { _, state, _ in
                state = true
            }
            .onChanged { value in
                isTransforming = true
                onPreview(
                    liveScale,
                    FreeStickerBoardLayout.normalizedRotation(
                        baseRotation + value.degrees
                    ),
                    isMagnifying,
                    true
                )
            }
            .onEnded { value in
                let rawRotation = baseRotation + value.degrees
                let snappedRotation = FreeStickerBoardLayout.snappedRotation(rawRotation)
                onTransform(nil, snappedRotation)
                if abs(snappedRotation - rawRotation) > 0.001 {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
    }
}

private struct StickerSelectionBoundary: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color.appCard, lineWidth: 5)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.appCherry.opacity(0.92), lineWidth: 1.5)
            }
            .padding(3)
            .shadow(color: Color.appChocolate.opacity(0.14), radius: 3, y: 2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The scale and angle readout, sized to sit on a sticker rather than banner
/// across the screen. Two short numbers is all this needs to say.
private struct StickerTransformBadge: View {
    let preview: StickerTransformPreview

    var body: some View {
        HStack(spacing: 5) {
            Text(verbatim: "\(Int((preview.scale * 100).rounded()))%")
            Text(verbatim: "\(Int(preview.rotation.rounded()))°")
        }
        .font(.system(size: 10, weight: .black, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.appInk)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.appCard.opacity(0.95), in: Capsule())
        .overlay(Capsule().stroke(Color.appCherry.opacity(0.3), lineWidth: 1))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The corner handle. One finger sets both size and angle: how far it is from the
/// centre is the size, which way it points is the angle. A pinch would need two
/// fingers inside a sticker barely wider than a thumb.
private struct StickerTransformHandle: View {
    let center: CGPoint
    let side: CGFloat
    let scale: CGFloat
    let rotationDegrees: Double
    let onDrag: (CGPoint) -> Void
    let onDone: () -> Void

    private var handlePoint: CGPoint {
        FreeStickerBoardLayout.handlePosition(
            center: center,
            side: side,
            scale: scale,
            rotationDegrees: rotationDegrees
        )
    }

    private var donePoint: CGPoint {
        FreeStickerBoardLayout.handlePosition(
            center: center,
            side: side,
            scale: scale,
            rotationDegrees: rotationDegrees + 180
        )
    }

    var body: some View {
        ZStack {
            // Outline of what is being adjusted.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.appCherry.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                .frame(width: side * scale, height: side * scale)
                .rotationEffect(.degrees(rotationDegrees))
                .position(center)
                .allowsHitTesting(false)

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.appInk.opacity(0.82), in: Circle())
                .overlay(Circle().stroke(Color.appCard, lineWidth: 2))
                .position(donePoint)
                .onTapGesture { onDone() }

            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.appPinkInk)
                .frame(width: 38, height: 38)   // a comfortable target, not a dot
                .background(Color.appCard, in: Circle())
                .overlay(Circle().stroke(Color.appCherry, lineWidth: 2))
                .softShadow()
                .position(handlePoint)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
                        .onChanged { onDrag($0.location) }
                )
        }
    }
}
