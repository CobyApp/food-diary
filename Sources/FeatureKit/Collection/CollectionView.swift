import SwiftUI
import ComposableArchitecture

public struct CollectionView: View {
    @Bindable var store: StoreOf<CollectionFeature>
    @State private var confirmingDeletion = false
    @State private var pendingSingleDeleteID: UUID?
    public init(store: StoreOf<CollectionFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    public var body: some View {
        ScreenScaffold(title: "컬렉션") {
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

                headerButton(systemImage: "person.crop.circle.fill", color: .appPink) {
                    store.send(.profileButtonTapped)
                }
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
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if let symbol = CutoutDecoration(label: cutout.label).symbol {
                                    KitschIcon(symbol, tint: .appPinkInk, background: .appPink, size: 34)
                                        .padding(5)
                                }
                            }
                            .rotationEffect(.degrees(index.isMultiple(of: 3) ? -1.2 : index.isMultiple(of: 2) ? 1 : 0))
                            .opacity(
                                store.isEditing && !store.selectedCutoutIDs.contains(cutout.id)
                                    ? 0.62
                                    : 1
                            )
                        }
                        .buttonStyle(KitschPressStyle())
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
            store.send(.profileCheck)
        }
        .sheet(item: $store.scope(state: \.achievements, action: \.achievements)) { achStore in
            AchievementsView(store: achStore)
        }
        .sheet(item: $store.scope(state: \.recap, action: \.recap)) { recapStore in
            RecapView(store: recapStore)
        }
        .sheet(item: $store.scope(state: \.profile, action: \.profile)) { profileStore in
            ProfileView(store: profileStore)
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
