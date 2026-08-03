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
                        Annotation(
                            meal.place?.name ?? "",
                            coordinate: CLLocationCoordinate2D(
                                latitude: c.latitude,
                                longitude: c.longitude
                            ),
                            anchor: .bottom
                        ) {
                            Button { store.send(.pinTapped(meal.id)) } label: {
                                pin(meal, isSelected: store.selectedMealID == meal.id)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(meal.place?.name ?? L10n.text("한 끼"))
                            .accessibilityHint(L10n.text("음식 스티커를 눌러 추억을 펼쳐보세요"))
                            .zIndex(store.selectedMealID == meal.id ? 10 : 1)
                        }
                    }
                }
            }
            .mapStyle(.standard(
                elevation: .flat,
                emphasis: .muted,
                pointsOfInterest: .excludingAll,
                showsTraffic: false
            ))
            .ignoresSafeArea()
            .overlay {
                ZStack {
                    Color.appMilk.opacity(0.07)
                    Image("StickerPaper")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.08)
                        .blendMode(.multiply)
                    LinearGradient(
                        colors: [
                            Color.appMilk.opacity(0.18),
                            .clear,
                            Color.appPink.opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .allowsHitTesting(false)
            }

            if store.isLoading && store.pins.isEmpty {
                KitschLoadingView(
                    "지도를 정리하는 중",
                    messages: ["삭제한 기록도 깔끔하게 정리하고 있어요"],
                    compact: true
                )
                .padding(.horizontal, 32)
                .padding(.bottom, 100)
            } else if store.pins.isEmpty {
                EmptyState(systemImage: "map", title: "아직 지도에 찍힌 곳이 없어요",
                           subtitle: "위치가 있는 사진으로 한 끼를 담아보세요!")
                    .padding(.horizontal, 28)
                    .padding(.bottom, 120)
            }

            if let meal = store.selectedMeal {
                FoodInfoCard(entry: meal) { store.send(.dismissCard) }
                    .padding(.horizontal, 16).padding(.bottom, 100)
                    .transition(.scale(scale: 0.96, anchor: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: store.selectedMealID)
        .animation(.easeInOut(duration: 0.25), value: store.isLoading)
        .task { store.send(.onAppear) }
    }

    private func pin(_ meal: FoodEntrySnapshot, isSelected: Bool) -> some View {
        FoodStickerMapPin(
            fileName: meal.fileName,
            extraCount: 0,
            isSelected: isSelected
        )
        .scaleEffect(isSelected ? 1.13 : 1)
        .rotationEffect(.degrees(isSelected ? 0 : -1.2))
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: isSelected)
    }

}

private struct FoodStickerMapPin: View {
    let fileName: String?
    let extraCount: Int
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.appPink.opacity(0.32))
                    .frame(width: 86, height: 86)
                    .transition(.scale.combined(with: .opacity))
            }

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appCard)
                .frame(width: 72, height: 70)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.appCard, lineWidth: 6)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            isSelected ? Color.appCherry : Color.appPinkInk.opacity(0.72),
                            lineWidth: isSelected ? 3.5 : 2.5
                        )
                }

            if let fileName {
                CutoutImage(fileName: fileName, maxPixelDimension: 200)
                    .frame(width: 62, height: 62)
            }

            if extraCount > 0 {
                Text("+\(extraCount)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(Color.appCherry, in: Capsule())
                    .overlay(Capsule().stroke(Color.appCard, lineWidth: 2))
                    .offset(x: 27, y: -31)
            }
        }
        .frame(width: 84, height: 78)
        .shadow(color: Color.appChocolate.opacity(0.22), radius: 0, x: 3, y: 4)
    }
}
