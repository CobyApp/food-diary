import SwiftUI
import ComposableArchitecture
import Models

public struct CollectionView: View {
    @Bindable var store: StoreOf<CollectionFeature>
    @State private var pendingSingleDeleteID: UUID?
    @State private var activeStickerID: UUID?
    /// Where the carried sticker is right now, so the bin knows when it is over it.
    @State private var carriedCenter: CGPoint?
    @State private var isOverRemoveZone = false
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

            if let id = pendingSingleDeleteID,
               store.cutouts.contains(where: { $0.id == id }) {
                ConfirmCard(
                    title: "이 음식을 완전히 삭제할까요?",
                    message: "보드에서 내리는 것과 달라요. 서랍에서도 사라지고 되돌릴 수 없어요.",
                    confirmTitle: "완전 삭제",
                    onConfirm: {
                        store.send(.deleteCutoutsConfirmed([id]))
                        pendingSingleDeleteID = nil
                    },
                    onCancel: { pendingSingleDeleteID = nil }
                )
                .transition(.opacity)
                .zIndex(2_000)
            }
        }
        .animation(
            .spring(response: 0.3, dampingFraction: 0.86),
            value: pendingSingleDeleteID
        )
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

            if let id = store.selectedCutoutID,
               let cutout = store.cutouts.first(where: { $0.id == id }) {
                FoodInfoCard(entry: cutout) { store.send(.dismissCutoutDetail) }
                    .padding(.horizontal, 16)
                    .padding(.bottom, Self.tabBarInset + 8)
                    .transition(
                        .scale(scale: 0.96, anchor: .bottom).combined(with: .opacity)
                    )
            }
        }
        .animation(
            .spring(response: 0.34, dampingFraction: 0.82),
            value: store.selectedCutoutID
        )
    }

    /// Out only while a sticker is being carried. Dropping a sticker here takes it
    /// off the board and back into the drawer — deliberately not a bin, because
    /// nothing is deleted. Deleting a food for good happens in the drawer.
    private var removeZone: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(isOverRemoveZone ? Color.appBlueInk : Color.appCard)
                    .frame(width: isOverRemoveZone ? 86 : 66, height: isOverRemoveZone ? 86 : 66)
                    .overlay {
                        Circle().stroke(
                            isOverRemoveZone ? Color.appCard : Color.appBlueInk.opacity(0.55),
                            style: StrokeStyle(lineWidth: 2.5, dash: isOverRemoveZone ? [] : [5, 4])
                        )
                    }
                    .softShadow()

                Image(systemName: isOverRemoveZone
                    ? "tray.and.arrow.down.fill"
                    : "tray.and.arrow.down")
                    .font(.system(size: isOverRemoveZone ? 30 : 24, weight: .black))
                    .foregroundStyle(isOverRemoveZone ? Color.appCard : Color.appBlueInk)
                    .rotationEffect(.degrees(isOverRemoveZone ? -12 : 0))
            }

            Text(isOverRemoveZone ? "놓으면 서랍으로 가요" : "여기로 끌면 보드에서 내려요")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(isOverRemoveZone ? Color.appBlueInk : Color.appMuted)
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
                                VStack(spacing: 6) {
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

                                drawerCaption(for: cutout)
                                }
                            }
                            .buttonStyle(KitschPressStyle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    pendingSingleDeleteID = cutout.id
                                    showingCutoutDrawer = false
                                } label: {
                                    Label("완전 삭제", systemImage: "trash")
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

    /// A food's rating and tags under its picture.
    ///
    /// Always the same height, whether or not there is anything to show: the grid
    /// sizes a row to its tallest cell, so a caption that varies left the rows
    /// ragged.
    private func drawerCaption(for cutout: FoodEntrySnapshot) -> some View {
        let info = store.cutoutMealInfo[cutout.id]
        return VStack(spacing: 3) {
            if let rating = info?.rating {
                StickerRatingBadge(rating: rating)
            }
            if let tags = info?.tags, !tags.isEmpty {
                TagChipRow(tags, limit: 2)
            }
        }
        .frame(height: Self.drawerCaptionHeight, alignment: .top)
    }

    private static let drawerCaptionHeight: CGFloat = 46

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
                    StickerTile(tint: .rotating(index)) {
                            CutoutImage(fileName: cutout.fileName)
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
                    .onTapGesture { store.send(.cutoutTapped(cutout.id)) }
                    .position(point)
                    .modifier(
                        FreeStickerDrag(
                            position: point,
                            rotationDegrees: savedPlacement?.rotation
                                ?? FreeStickerBoardLayout.defaultRotation(index: index),
                            onActiveChange: { active in
                                activeStickerID = active ? cutout.id : nil
                                if !active {
                                    carriedCenter = nil
                                    isOverRemoveZone = false
                                }
                            },
                            onDragChange: { centre in
                                carriedCenter = centre
                                let over = FreeStickerBoardLayout.isOverRemoveZone(
                                    centre, width: width, height: height
                                )
                                if over != isOverRemoveZone {
                                    isOverRemoveZone = over
                                    #if canImport(UIKit)
                                    // Felt, not just seen: you know before you let go.
                                    UIImpactFeedbackGenerator(style: .rigid)
                                        .impactOccurred(intensity: over ? 1 : 0.4)
                                    #endif
                                }
                            },
                            onMove: { destination in
                                if FreeStickerBoardLayout.isOverRemoveZone(
                                    destination, width: width, height: height
                                ) {
                                    // Off the board, into the drawer. The food is
                                    // not deleted, so there is nothing to confirm.
                                    removeFromBoard(cutout)
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
                }


                if activeStickerID != nil {
                    removeZone
                        .position(
                            FreeStickerBoardLayout.removeZoneCenter(width: width, height: height)
                        )
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .zIndex(500)
                }
            }
            .frame(width: width, height: height)
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: activeStickerID != nil)
            .animation(.spring(response: 0.26, dampingFraction: 0.6), value: isOverRemoveZone)
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
            .highPriorityGesture(dragGesture)
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
