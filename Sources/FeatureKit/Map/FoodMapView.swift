import SwiftUI
import MapKit
import ComposableArchitecture
import Models

public struct FoodMapView: View {
    @Bindable var store: StoreOf<FoodMapFeature>
    public init(store: StoreOf<FoodMapFeature>) { self.store = store }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Map(initialPosition: .automatic) {
                ForEach(store.pins) { meal in
                    if let c = meal.place?.coordinate {
                        Annotation(meal.place?.name ?? "",
                                   coordinate: CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude)) {
                            Button { store.send(.pinTapped(meal.id)) } label: { pin(meal) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .ignoresSafeArea()

            Text("맛집 지도 🗺️")
                .font(.appTitle).foregroundStyle(.appInk)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 8)

            if store.pins.isEmpty {
                EmptyState(systemImage: "map", title: "아직 지도에 찍힌 곳이 없어요",
                           subtitle: "위치가 있는 사진으로 한 끼를 담아보세요!")
                    .padding(.bottom, 120)
            }

            if let meal = store.selectedMeal {
                selectedCard(meal)
                    .padding(.horizontal, 16).padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: store.selectedMealID)
        .task { store.send(.onAppear) }
    }

    private func pin(_ meal: MealSnapshot) -> some View {
        ZStack {
            Circle().fill(Color.appCard).frame(width: 52, height: 52).softShadow()
            if let first = meal.cutouts.first {
                CutoutImage(fileName: first.fileName).frame(width: 40, height: 40)
            } else {
                Text("🍽").font(.system(size: 22))
            }
        }
        .overlay(Circle().strokeBorder(Color.appBlue, lineWidth: 2))
    }

    private func selectedCard(_ meal: MealSnapshot) -> some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    PastelChip(meal.place?.name ?? "한 끼", glyph: "✦", tone: .blue)
                    Spacer()
                    Button { store.send(.dismissCard) } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.appMuted)
                    }
                    .buttonStyle(.plain)
                }
                Text(meal.eatenAt.formatted(.dateTime.month().day().weekday()))
                    .font(.appCaption).foregroundStyle(.appMuted)
                if !meal.cutouts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(meal.cutouts) { c in
                                CutoutImage(fileName: c.fileName).frame(width: 56, height: 56)
                            }
                        }
                    }
                }
            }
        }
    }
}
