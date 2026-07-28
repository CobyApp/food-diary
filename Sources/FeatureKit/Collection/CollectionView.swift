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
    @State private var draftRecapStartDate = Date()
    @State private var draftRecapEndDate = Date()
    @AppStorage("collection.freeStickerBoard.v1") private var savedStickerPlacements = ""
    @AppStorage("collection.stickerBoardTheme.v1")
    private var selectedThemeRaw = StickerBoardTheme.strawberryCheck.rawValue
    @AppStorage("collection.stickerBoardFrame.v1")
    private var selectedFrameRaw = StickerBoardFrame.softPaper.rawValue
    public init(store: StoreOf<CollectionFeature>) { self.store = store }

    private var selectedTheme: StickerBoardTheme {
        StickerBoardTheme(rawValue: selectedThemeRaw) ?? .strawberryCheck
    }

    private var selectedFrame: StickerBoardFrame {
        StickerBoardFrame(rawValue: selectedFrameRaw) ?? .softPaper
    }

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

                headerButton(systemImage: "rosette", color: .appButterInk) {
                    store.send(.achievementsButtonTapped)
                }
            }

            recapPeriodCard
            boardStylePicker

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
                StickerBoardSurface(
                    theme: selectedTheme,
                    frame: selectedFrame
                )

                ForEach(Array(store.cutouts.enumerated()), id: \.element.id) { index, cutout in
                    let savedPlacement = stickerPlacements[cutout.id.uuidString]
                    let point = FreeStickerBoardLayout.point(
                        for: savedPlacement,
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
                            baseScale: savedPlacement?.displayScale ?? 1,
                            baseRotation: savedPlacement?.rotation
                                ?? FreeStickerBoardLayout.defaultRotation(index: index),
                            enabled: !store.isEditing,
                            isActive: activeStickerID == cutout.id,
                            onActiveChange: { active in
                                activeStickerID = active ? cutout.id : nil
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

            Text("보드 모양")
                .font(.appCaption)
                .foregroundStyle(.appPinkInk)
                .padding(.top, 2)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(StickerBoardFrame.allCases) { frame in
                        let selected = selectedFrame == frame
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                selectedFrameRaw = frame.rawValue
                            }
                        } label: {
                            VStack(spacing: 6) {
                                StickerBoardSurface(
                                    theme: selectedTheme,
                                    frame: frame,
                                    borderOpacity: selected ? 0.72 : 0.30
                                )
                                .frame(width: 74, height: 52)
                                .overlay(alignment: .bottomTrailing) {
                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .black))
                                            .foregroundStyle(.white)
                                            .frame(width: 20, height: 20)
                                            .background(selectedTheme.accent, in: Circle())
                                            .overlay(Circle().stroke(Color.appCard, lineWidth: 2))
                                            .offset(x: 4, y: 4)
                                    }
                                }

                                Text(L10n.text(frame.titleKey))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        selected ? selectedTheme.accent : Color.appInk
                                    )
                                    .lineLimit(1)
                            }
                            .padding(7)
                            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(
                                        selected
                                            ? selectedTheme.accent.opacity(0.65)
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
    let cutout: CutoutSnapshot
    let info: CutoutMealInfo?
    let theme: StickerBoardTheme
    let onClose: () -> Void

    private var review: String {
        info?.memo.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
                        Text("나의 한 줄평")
                            .font(.appSection)
                            .foregroundStyle(.appInk)
                        Text(review.isEmpty ? L10n.text("아직 한 줄평이 없어요") : "“\(review)”")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(review.isEmpty ? Color.appMuted : Color.appInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
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

private struct FreeStickerDrag: ViewModifier {
    let position: CGPoint
    let baseScale: CGFloat
    let baseRotation: Double
    let enabled: Bool
    let isActive: Bool
    let onActiveChange: (Bool) -> Void
    let onMove: (CGPoint) -> Void
    let onTransform: (Double?, Double?) -> Void

    @GestureState private var translation: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var gestureRotation: Angle = .zero
    @GestureState private var isDragging = false
    @GestureState private var isMagnifying = false
    @GestureState private var isRotating = false

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
                    StickerTransformGuide(
                        scale: liveScale,
                        rotation: liveRotation
                    )
                    // Keep the readout upright and the same visual size while
                    // the selected sticker itself rotates and scales.
                    .scaleEffect(1 / max(liveScale, 0.01))
                    .rotationEffect(.degrees(-liveRotation))
                    .transition(.scale(scale: 0.84).combined(with: .opacity))
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
            .offset(translation)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isActive)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isInteracting)
            .highPriorityGesture(dragGesture, including: enabled ? .all : .none)
            .simultaneousGesture(magnifyGesture, including: enabled ? .all : .none)
            .simultaneousGesture(rotationGesture, including: enabled ? .all : .none)
            .onChange(of: isInteracting) { _, active in
                onActiveChange(active)
                if active {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
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

private struct StickerTransformGuide: View {
    let scale: CGFloat
    let rotation: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    Color.appCherry,
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
                .padding(2)

            guideHandle(alignment: .topLeading)
            guideHandle(alignment: .bottomTrailing)
        }
        .overlay(alignment: .top) {
            HStack(spacing: 7) {
                Label(
                    "\(Int((scale * 100).rounded()))%",
                    systemImage: "arrow.up.left.and.arrow.down.right"
                )
                Divider()
                    .frame(height: 12)
                    .overlay(Color.appPink.opacity(0.7))
                Label(
                    "\(Int(rotation.rounded()))°",
                    systemImage: "rotate.right"
                )
            }
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.appPinkInk, in: Capsule())
            .overlay(Capsule().stroke(Color.appCard, lineWidth: 2))
            .shadow(color: Color.appChocolate.opacity(0.18), radius: 4, y: 2)
            .offset(y: -29)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func guideHandle(alignment: Alignment) -> some View {
        Circle()
            .fill(Color.appCard)
            .frame(width: 13, height: 13)
            .overlay(Circle().stroke(Color.appCherry, lineWidth: 2))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .padding(1)
    }
}
