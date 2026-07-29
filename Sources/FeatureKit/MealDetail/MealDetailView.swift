import SwiftUI
import ComposableArchitecture

public struct MealDetailView: View {
    @Bindable var store: StoreOf<MealDetailFeature>
    @State private var confirmingDelete = false
    public init(store: StoreOf<MealDetailFeature>) { self.store = store }

    public var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                if let entry = store.entry {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(entry.place?.name ?? L10n.text("한 끼 기록"))
                            .font(.appDisplay).foregroundStyle(.appInk)

                        HStack(spacing: 8) {
                            PastelChip(entry.eatenAt.formatted(.dateTime.month().day().weekday()),
                                       symbol: "calendar", tone: .pink)
                            if entry.rating != nil { StarRating(rating: entry.rating) }
                        }

                        if !entry.tags.isEmpty {
                            SoftCard {
                                TagFlow(entry.tags) { TagChip($0) }
                            }
                        }

                        // One record, one food.
                        StickerTile(tint: .pink) {
                            CutoutImage(fileName: entry.fileName)
                        }
                        .frame(maxWidth: 260)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    KitschLoadingView(
                        "한 끼 기록을 펼치는 중",
                        messages: ["잠시만 기다려주세요"],
                        compact: true
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                }
            }
        }
        .navigationTitle("한 끼 기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appMilk, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("삭제") { confirmingDelete = true }
                    .foregroundStyle(Color.appPinkInk)
            }
        }
        .confirmationDialog("이 기록을 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { store.send(.deleteTapped) }
            Button("취소", role: .cancel) {}
        }
        .task { store.send(.task) }
    }
}
