import SwiftUI
import ComposableArchitecture

public struct MealDetailView: View {
    @Bindable var store: StoreOf<MealDetailFeature>
    @State private var confirmingDelete = false
    public init(store: StoreOf<MealDetailFeature>) { self.store = store }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            ScrollView {
                if let meal = store.meal {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(meal.place?.name ?? "한 끼 기록")
                            .font(.appDisplay).foregroundStyle(.appInk)

                        HStack(spacing: 8) {
                            PastelChip(meal.eatenAt.formatted(.dateTime.month().day().weekday()),
                                       glyph: "📅", tone: .pink)
                            if meal.rating != nil { StarRating(rating: meal.rating) }
                        }

                        if !meal.memo.isEmpty {
                            SoftCard {
                                Text(meal.memo).font(.appBody).foregroundStyle(.appInk)
                            }
                        }

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Array(meal.cutouts.enumerated()), id: \.element.id) { index, cutout in
                                StickerTile(tint: .rotating(index)) {
                                    CutoutImage(fileName: cutout.fileName)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ProgressView().tint(.appBlue).padding(.top, 80)
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
