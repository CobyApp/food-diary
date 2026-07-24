import SwiftUI
import ComposableArchitecture

public struct MealDetailView: View {
    @Bindable var store: StoreOf<MealDetailFeature>
    @State private var confirmingDelete = false
    public init(store: StoreOf<MealDetailFeature>) { self.store = store }

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    public var body: some View {
        ScrollView {
            if let meal = store.meal {
                VStack(alignment: .leading, spacing: 16) {
                    if let place = meal.place { Text(place.name).font(.title2.bold()) }
                    Text(meal.eatenAt, style: .date).foregroundStyle(.secondary)
                    if let rating = meal.rating { Text(String(repeating: "⭐️", count: rating)) }
                    if !meal.memo.isEmpty { Text(meal.memo) }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(meal.cutouts) { cutout in
                            CutoutImage(fileName: cutout.fileName).frame(height: 100)
                        }
                    }
                }
                .padding()
            } else {
                ProgressView()
            }
        }
        .navigationTitle("한 끼 기록")
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("삭제", role: .destructive) { confirmingDelete = true }
            }
        }
        .confirmationDialog("이 기록을 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { store.send(.deleteTapped) }
            Button("취소", role: .cancel) {}
        }
        .task { store.send(.task) }
    }
}
