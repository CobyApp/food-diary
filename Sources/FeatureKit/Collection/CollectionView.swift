import SwiftUI
import ComposableArchitecture
import Models

public struct CollectionView: View {
    @Bindable var store: StoreOf<CollectionFeature>
    @State private var confirmingDeletion = false
    @State private var pendingSingleDeleteID: UUID?
    @State private var activeStickerID: UUID?
    /// Where the carried sticker is right now, so the bin knows when it is over it.
    @State private var carriedCenter: CGPoint?
    @State private var isOverTrash = false
    @State private var stickerPlacements: [String: StickerBoardPlacement] = [:]
    @State private var showingBoardStylePicker = false
    @State private var showingCutoutDrawer = false
    /// Measured height of the floating chrome, used as the board's top inset.
    @State private var controlsHeight: CGFloat = 0
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

    /// Space the floating tab bar takes at the bottom of the board.
    private static let tabBarInset: CGFloat = 96

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
        }
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

    /// One screen, no scrolling: a desktop does not scroll, and the drawer holds
    /// whatever does not fit.
    private var canvas: some View {
        ZStack(alignment: .bottom) {
            if boardCutouts.isEmpty {
                emptyBoard
                    .padding(.horizontal, 18)
                    .padding(.top, controlsHeight + 28)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                freeStickerBoard
            }

            if store.isEditing, !boardCutouts.isEmpty {
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
                .padding(.bottom, 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// The bin, out only while a sticker is being carried. It opens its lid when
    /// the sticker is over it, so you know what letting go will do.
    private var trashZone: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(isOverTrash ? Color.appCherry : Color.appCard)
                    .frame(width: isOverTrash ? 86 : 66, height: isOverTrash ? 86 : 66)
                    .overlay {
                        Circle().stroke(
                            isOverTrash ? Color.appCard : Color.appCherry.opacity(0.55),
                            style: StrokeStyle(lineWidth: 2.5, dash: isOverTrash ? [] : [5, 4])
                        )
                    }
                    .softShadow()

                Image(systemName: isOverTrash ? "trash.fill" : "trash")
                    .font(.system(size: isOverTrash ? 30 : 24, weight: .black))
                    .foregroundStyle(isOverTrash ? Color.appCard : Color.appCherry)
                    .rotationEffect(.degrees(isOverTrash ? -12 : 0))
            }

            Text(isOverTrash ? "놓으면 삭제해요" : "여기로 끌어오면 삭제")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(isOverTrash ? Color.appCherry : Color.appMuted)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.appCard.opacity(0.92), in: Capsule())
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
                    store.send(.recapButtonTapped(boardCutouts))
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
            // Exactly the space on screen: with no scrolling there is nowhere
            // for the board to grow to.
            let height = proxy.size.height
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
                    Button {
                        // Outside edit mode a sticker is just an object on the
                        // board; its actions live in the long-press menu.
                        guard store.isEditing else { return }
                        store.send(.selectionToggled(cutout.id))
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
                        .opacity(
                            store.isEditing && !store.selectedCutoutIDs.contains(cutout.id)
                                ? 0.62
                                : 1
                        )
                    }
                    .buttonStyle(.plain)
                    .position(point)
                    .modifier(
                        FreeStickerDrag(
                            position: point,
                            rotationDegrees: savedPlacement?.rotation
                                ?? FreeStickerBoardLayout.defaultRotation(index: index),
                            enabled: !store.isEditing,
                            onActiveChange: { active in
                                activeStickerID = active ? cutout.id : nil
                                if !active {
                                    carriedCenter = nil
                                    isOverTrash = false
                                }
                            },
                            onDragChange: { centre in
                                carriedCenter = centre
                                let over = FreeStickerBoardLayout.isOverTrash(
                                    centre, width: width, height: height
                                )
                                if over != isOverTrash {
                                    isOverTrash = over
                                    #if canImport(UIKit)
                                    // Felt, not just seen: you know before you let go.
                                    UIImpactFeedbackGenerator(style: .rigid)
                                        .impactOccurred(intensity: over ? 1 : 0.4)
                                    #endif
                                }
                            },
                            onMove: { destination in
                                if FreeStickerBoardLayout.isOverTrash(
                                    destination, width: width, height: height
                                ) {
                                    // Dropped on the bin: ask first, and leave the
                                    // sticker where it was until the answer comes.
                                    pendingSingleDeleteID = cutout.id
                                    confirmingDeletion = true
                                    return
                                }
                                stickerPlacements[cutout.id.uuidString] =
                                    FreeStickerBoardLayout.placement(
                                        for: destination,
                                        width: width,
                                        height: height,
                                        preserving: stickerPlacements[cutout.id.uuidString]
                                    )
                                persistStickerPlacements()
                            }
                        )
                    )
                    .zIndex(activeStickerID == cutout.id ? 100 : Double(index))
                    .contextMenu {
                        Button {
                            stickerPlacements.removeValue(forKey: cutout.id.uuidString)
                            persistStickerPlacements()
                        } label: {
                            Label("자리 원래대로", systemImage: "arrow.counterclockwise")
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


                if activeStickerID != nil {
                    trashZone
                        .position(
                            FreeStickerBoardLayout.trashCenter(width: width, height: height)
                        )
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .zIndex(500)
                }
            }
            .frame(width: width, height: height)
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: activeStickerID != nil)
            .animation(.spring(response: 0.26, dampingFraction: 0.6), value: isOverTrash)
        }
    }

    /// Four backgrounds, nothing else. The sheet already says what it is, so a
    /// second title and a card around a single row were just noise.
    private var boardStylePicker: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
            spacing: 12
        ) {
            ForEach(StickerBoardTheme.allCases) { theme in
                let selected = selectedTheme == theme
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selectedThemeRaw = theme.rawValue
                    }
                } label: {
                    VStack(spacing: 8) {
                        StickerBoardThemeBackground(theme: theme)
                            .frame(height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(alignment: .bottomTrailing) {
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(theme.accent, in: Circle())
                                        .overlay(Circle().stroke(Color.appCard, lineWidth: 2))
                                        .padding(7)
                                }
                            }

                        Text(L10n.text(theme.titleKey))
                            .font(.appCaption)
                            .foregroundStyle(selected ? theme.accent : Color.appInk)
                            .lineLimit(1)
                    }
                    .padding(8)
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                selected ? theme.accent : Color.appChocolate.opacity(0.10),
                                lineWidth: selected ? 2 : 1
                            )
                    }
                }
                .buttonStyle(KitschPressStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
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

    /// Writes a live handle drag into the sticker's scale and angle.
    ///
    /// Position is left alone on purpose: re-clamping it on every change moved the
    /// sticker's centre mid-drag, which moved the very point the deltas are
    /// measured from. It is clamped once the finger lifts.
    /// Once the finger lifts: snap to the useful values, keep the sticker on the
    /// board at its new size, and save.
    /// Takes a sticker off the board. The food itself stays in the drawer.
    private func removeFromBoard(_ cutout: FoodEntrySnapshot) {
        offBoardIDs.insert(cutout.id.uuidString)
        stickerPlacements.removeValue(forKey: cutout.id.uuidString)
        persistOffBoardIDs()
        persistStickerPlacements()
    }

    /// Puts a sticker back out, in the first slot nothing else is sitting in.
    private func addToBoard(_ cutout: FoodEntrySnapshot) {
        // The board is exactly the screen now, minus the floating tab bar.
        let width = max(UIScreen.main.bounds.width, 284)
        let height = max(UIScreen.main.bounds.height - Self.tabBarInset, 320)
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
    /// Tilt and hold to read the place names on that half of the board. Driven by
    /// `.task(id:)`, so changing or releasing the tilt cancels a pending reveal.
    @ViewBuilder
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

private extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}

/// Drag a sticker around the board. That is the whole interaction: a sticker is
/// something you move, and it answers with a tap you can feel.
private struct FreeStickerDrag: ViewModifier {
    let position: CGPoint
    let rotationDegrees: Double
    let enabled: Bool
    let onActiveChange: (Bool) -> Void
    let onDragChange: (CGPoint) -> Void
    let onMove: (CGPoint) -> Void

    @GestureState private var translation: CGSize = .zero
    @GestureState private var isDragging = false

    func body(content: Content) -> some View {
        content
            // Lifts a little while held, so it reads as picked up off the board.
            .scaleEffect(isDragging ? 1.06 : 1)
            .rotationEffect(.degrees(rotationDegrees))
            .shadow(
                color: Color.appPinkInk.opacity(isDragging ? 0.24 : 0),
                radius: isDragging ? 16 : 0,
                y: isDragging ? 10 : 0
            )
            .offset(translation)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isDragging)
            .highPriorityGesture(dragGesture, including: enabled ? .all : .none)
            .onChange(of: isDragging) { _, dragging in
                onActiveChange(dragging)
                #if canImport(UIKit)
                // One tap on pick-up, a softer one on set-down.
                UIImpactFeedbackGenerator(style: dragging ? .rigid : .soft)
                    .impactOccurred(intensity: dragging ? 0.9 : 0.6)
                #endif
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
            .onChanged { value in
                onDragChange(CGPoint(
                    x: position.x + value.translation.width,
                    y: position.y + value.translation.height
                ))
            }
            .onEnded { value in
                onMove(CGPoint(
                    x: position.x + value.translation.width,
                    y: position.y + value.translation.height
                ))
            }
    }
}

/// The scale and angle readout, sized to sit on a sticker rather than banner
/// across the screen. Two short numbers is all this needs to say.
/// The corner handle. One finger sets both size and angle: how far it is from the
/// centre is the size, which way it points is the angle. A pinch would need two
/// fingers inside a sticker barely wider than a thumb.
///
/// No outline is drawn around the sticker. A cutout keeps its own proportions
/// inside a square slot, so the food is almost never square — any box would sit
/// well outside it and read as the sticker having escaped its guide. The sticker
/// being adjusted glows instead.
