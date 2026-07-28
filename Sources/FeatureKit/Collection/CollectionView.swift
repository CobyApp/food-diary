import SwiftUI
import ComposableArchitecture
import Models

public struct CollectionView: View {
    @Bindable var store: StoreOf<CollectionFeature>
    @State private var confirmingDeletion = false
    @State private var pendingSingleDeleteID: UUID?
    @State private var motion = ParallaxMotion()
    @State private var peelCoordinator = PeelCoordinator()
    @State private var isSpilling = false
    @State private var revealedColumn: Int?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    public init(store: StoreOf<CollectionFeature>) { self.store = store }

    private var columnCount: Int { horizontalSizeClass == .regular ? 5 : 3 }
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
    }
    private var tiltCandidateColumn: Int? {
        StickerBoardMotion.revealedColumn(
            tiltX: motion.tiltX,
            columnCount: columnCount,
            threshold: 0.55
        )
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
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(store.cutouts.enumerated()), id: \.element.id) { index, cutout in
                        let cell = CGPoint(
                            x: index % columnCount,
                            y: index / columnCount
                        )
                        Button {
                            store.send(
                                store.isEditing
                                    ? .selectionToggled(cutout.id)
                                    : .cutoutTapped(cutout.id)
                            )
                        } label: {
                            let isFlipped = store.flippedCutoutID == cutout.id
                            let lean = StickerBoardMotion.lean(
                                index: index,
                                tiltX: motion.tiltX,
                                tiltY: motion.tiltY
                            )
                            ZStack {
                                // FRONT
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
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    if let symbol = CutoutDecoration(label: cutout.label).symbol {
                                        KitschIcon(symbol, tint: .appPinkInk, background: .appPink, size: 34)
                                            .padding(5)
                                    }
                                }
                                .overlay(alignment: .bottom) {
                                    if revealedColumn == index % columnCount,
                                       let place = store.cutoutMealInfo[cutout.id]?.placeName,
                                       !place.isEmpty {
                                        PastelChip(place, tone: .pink)
                                            .padding(5)
                                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                                    }
                                }
                                .opacity(isFlipped ? 0 : 1)

                                // BACK
                                cutoutBack(cutout)
                                    .opacity(isFlipped ? 1 : 0)
                                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                            }
                            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                            .rotationEffect(.degrees(
                                (index.isMultiple(of: 3) ? -1.2 : index.isMultiple(of: 2) ? 1 : 0)
                                    + StickerBoardMotion.leanRotation(
                                        index: index,
                                        tiltX: motion.tiltX
                                    )
                            ))
                            .offset(
                                x: lean.width,
                                y: lean.height + (
                                    isSpilling
                                        ? 720 + CGFloat(index / columnCount) * 18
                                        : 0
                                )
                            )
                            .opacity(
                                isSpilling
                                    ? 0.05
                                    : store.isEditing && !store.selectedCutoutIDs.contains(cutout.id)
                                    ? 0.62
                                    : 1
                            )
                            .animation(
                                isSpilling
                                    ? .easeIn(duration: 0.3).delay(
                                        StickerBoardMotion.spillDelay(index: index)
                                    )
                                    : .spring(response: 0.5, dampingFraction: 0.68).delay(
                                        StickerBoardMotion.spillDelay(index: index) * 0.35
                                    ),
                                value: isSpilling
                            )
                            .animation(
                                .interactiveSpring(response: 0.34, dampingFraction: 0.76),
                                value: lean
                            )
                        }
                        .buttonStyle(KitschPressStyle())
                        .peelable(
                            cell: cell,
                            coordinator: peelCoordinator,
                            enabled: !store.isEditing
                        )
                        .contextMenu {
                            Button {
                                store.send(.cutoutTapped(cutout.id))
                            } label: {
                                Label("기록 보기", systemImage: "book.pages")
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
            store.send(.onAppear)
            store.send(.streakOnAppear)
            motion.start()
        }
        .task(id: tiltCandidateColumn) {
            guard let candidate = tiltCandidateColumn else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    revealedColumn = nil
                }
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, tiltCandidateColumn == candidate else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                revealedColumn = candidate
            }
        }
        .onDisappear {
            motion.stop()
            peelCoordinator.release()
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
            .font(.appCaption)
            .foregroundStyle(.appBlueInk)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Color.appBlue.opacity(0.5), in: Capsule())
            .overlay {
                Capsule().stroke(Color.appBlueInk.opacity(0.35), lineWidth: 1.5)
            }
        }
        .buttonStyle(KitschPressStyle())
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
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.18), in: Circle())
                .overlay {
                    Circle().stroke(color.opacity(0.5), lineWidth: 1.5)
                }
                .softShadow()
        }
        .buttonStyle(KitschPressStyle())
    }
}
