import SwiftUI
import MapKit
import ComposableArchitecture
import Models

public struct FoodMapView: View {
    @Bindable var store: StoreOf<FoodMapFeature>
    @Environment(\.openURL) private var openURL

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

            if !store.pins.isEmpty {
                Text(L10n.format("map.records", store.pins.count))
                    .font(.appCaption)
                    .foregroundStyle(.appChocolate)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Color.appCard.opacity(0.94), in: Capsule())
                    .overlay {
                        Capsule().stroke(Color.appPink.opacity(0.9), lineWidth: 2)
                    }
                    .rotationEffect(.degrees(1.5))
                    .softShadow()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 16)
                    .safeAreaPadding(.top, 10)
                    .transition(.opacity)
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
                selectedCard(meal)
                    .padding(.horizontal, 16).padding(.bottom, 100)
                    .transition(.scale(scale: 0.96, anchor: .bottom).combined(with: .opacity))
            } else if !store.pins.isEmpty && !store.isLoading {
                Text("음식 스티커를 눌러 추억을 펼쳐보세요")
                    .font(.appCaption)
                    .foregroundStyle(.appChocolate)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(Color.appCard.opacity(0.94))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.appChocolate.opacity(0.14), lineWidth: 1.5)
                    }
                    .rotationEffect(.degrees(-1))
                    .softShadow()
                    .padding(.bottom, 100)
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.35), value: store.selectedMealID)
        .animation(.easeInOut(duration: 0.25), value: store.isLoading)
        .task { store.send(.onAppear) }
    }

    private func pin(_ meal: MealSnapshot, isSelected: Bool) -> some View {
        ZStack {
            FoodStickerPinShape()
                .fill(Color.appCard)
                .overlay {
                    FoodStickerPinShape()
                        .stroke(
                            isSelected ? Color.appCherry : Color.appPink,
                            lineWidth: isSelected ? 4 : 3
                        )
                }
                .softShadow()
            if let first = meal.cutouts.first {
                CutoutImage(fileName: first.fileName, maxPixelDimension: 180)
                    .frame(width: 54, height: 54)
                    .offset(y: -5)
            }
            if meal.cutouts.count > 1 {
                Text("+\(meal.cutouts.count - 1)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(Color.appCherry, in: Capsule())
                    .overlay(Capsule().stroke(Color.appCard, lineWidth: 2))
                    .offset(x: 25, y: -30)
            }
        }
        .frame(width: 72, height: 80)
        .scaleEffect(isSelected ? 1.12 : 1)
        .rotationEffect(.degrees(isSelected ? 0 : -1.5))
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: isSelected)
    }

    private func selectedCard(_ meal: MealSnapshot) -> some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    if let first = meal.cutouts.first {
                        CutoutImage(fileName: first.fileName, maxPixelDimension: 260)
                            .frame(width: 88, height: 88)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            openPlaceInMaps(meal)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(meal.place?.name ?? L10n.text("한 끼"))
                                    .font(.appTitle)
                                    .foregroundStyle(.appInk)
                                    .lineLimit(2)
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.appPinkInk)
                            }
                        }
                        .buttonStyle(.plain)
                        if let address = meal.place?.address, !address.isEmpty {
                            Text(address)
                                .font(.appCaption)
                                .foregroundStyle(.appMuted)
                                .lineLimit(2)
                        }
                        HStack(spacing: 6) {
                            PastelChip(
                                meal.eatenAt.formatted(.dateTime.month().day()),
                                symbol: "calendar",
                                tone: .blue
                            )
                            if let rating = meal.rating {
                                HStack(spacing: 2) {
                                    ForEach(0..<rating, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.appButterInk)
                            }
                        }
                    }
                    Spacer()
                    Button { store.send(.dismissCard) } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.appInk)
                            .frame(width: 30, height: 30)
                            .background(Color.appCard, in: Circle())
                            .overlay {
                                Circle().stroke(
                                    Color.appChocolate.opacity(0.25),
                                    lineWidth: 1.5
                                )
                            }
                    }
                    .buttonStyle(.plain)
                }
                if meal.cutouts.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(meal.cutouts.dropFirst()) { cutout in
                                CutoutImage(fileName: cutout.fileName, maxPixelDimension: 160)
                                    .frame(width: 62, height: 62)
                            }
                        }
                    }
                }
                if !meal.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(meal.memo)
                        .font(.appBody)
                        .foregroundStyle(.appInk)
                        .lineLimit(3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appTileButter, in: RoundedRectangle(cornerRadius: 12))
                }
                Button {
                    openPlaceInMaps(meal)
                } label: {
                    Text("지도 앱에서 가게 보기")
                        .font(.appSection)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.appBlueInk, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.appCard, lineWidth: 2)
                                .padding(2)
                        }
                }
                .buttonStyle(KitschPressStyle())
            }
        }
    }

    private func openPlaceInMaps(_ meal: MealSnapshot) {
        guard let place = meal.place, let coordinate = place.coordinate else { return }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(
                name: "ll",
                value: "\(coordinate.latitude),\(coordinate.longitude)"
            ),
            URLQueryItem(name: "q", value: place.name),
        ]
        if let url = components?.url {
            openURL(url)
        }
    }
}

private struct FoodStickerPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bubble = CGRect(x: 2, y: 2, width: rect.width - 4, height: rect.height - 14)
        path.addRoundedRect(in: bubble, cornerSize: CGSize(width: 23, height: 23))
        path.move(to: CGPoint(x: rect.midX - 9, y: bubble.maxY - 2))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 1))
        path.addLine(to: CGPoint(x: rect.midX + 9, y: bubble.maxY - 2))
        path.closeSubpath()
        return path
    }
}
