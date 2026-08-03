import SwiftUI
import Models

/// The card a food opens: on the map when a pin is tapped, on the board when a
/// sticker is tapped. One view, so a tap answers the same way on both screens.
struct FoodInfoCard: View {
    let entry: FoodEntrySnapshot
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    StickerTile(tint: .pink) {
                        CutoutImage(fileName: entry.fileName, maxPixelDimension: 260)
                    }
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(-2))

                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            openInMaps()
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(entry.place?.name ?? L10n.text("한 끼"))
                                    .font(.appTitle)
                                    .foregroundStyle(.appInk)
                                    .lineLimit(2)
                                if entry.place?.coordinate != nil {
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption.bold())
                                        .foregroundStyle(.appPinkInk)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(entry.place?.coordinate == nil)

                        if let address = entry.place?.address, !address.isEmpty {
                            Text(address)
                                .font(.appCaption)
                                .foregroundStyle(.appMuted)
                                .lineLimit(2)
                        }

                        HStack(spacing: 6) {
                            PastelChip(
                                entry.eatenAt.formatted(.dateTime.month().day()),
                                symbol: "calendar",
                                tone: .blue
                            )
                            if let rating = entry.rating {
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

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.appPinkInk)
                            .frame(width: 30, height: 30)
                            .background(Color.appTilePink, in: Circle())
                            .overlay {
                                Circle().stroke(Color.appPinkInk.opacity(0.35), lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                }

                if !entry.tags.isEmpty {
                    TagChipRow(entry.tags, limit: 3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appTileButter, in: RoundedRectangle(cornerRadius: 12))
                }

                if entry.place?.coordinate != nil {
                    Button {
                        openInMaps()
                    } label: {
                        Label("지도 앱에서 가게 보기", systemImage: "arrow.up.right")
                    }
                    .buttonStyle(
                        KitschFilledButtonStyle(color: .appBlueInk, verticalPadding: 11)
                    )
                }
            }
        }
        .overlay(alignment: .top) {
            WashiTape(.appPink)
                .offset(y: -7)
        }
    }

    private func openInMaps() {
        guard let place = entry.place, let coordinate = place.coordinate else { return }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "q", value: place.name),
        ]
        if let url = components?.url {
            openURL(url)
        }
    }
}
