import SwiftUI
import Models

struct ResultCard: View {
    let cutout: FoodEntrySnapshot
    let info: GameResultInfo?
    let onAgain: () -> Void

    @State private var stamped = false

    var body: some View {
        ZStack {
            ConfettiBurst()
                .frame(width: 280, height: 280)
                .offset(y: -45)

            VStack(spacing: 18) {
                Text("TODAY'S PICK")
                    .font(.appCaption)
                    .tracking(2)
                    .foregroundStyle(.appPinkInk)
                StickerTile(tint: .pink) { CutoutImage(fileName: cutout.fileName) }
                    .frame(width: 224, height: 224)
                    .rotationEffect(.degrees(-2))
                    .overlay(alignment: .top) { WashiTape(.appButter).offset(y: -7) }
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                Text(info?.placeName.isEmpty == false ? info!.placeName : L10n.text("오늘의 한 끼"))
                    .font(.appDisplay).foregroundStyle(.appChocolate)
                    .multilineTextAlignment(.center)
                if let info {
                    if !info.dateText.isEmpty {
                        PastelChip(info.dateText, symbol: "calendar", tone: .pink)
                    }
                    if !info.tags.isEmpty {
                        TagChipRow(info.tags, limit: 3, size: .regular)
                            .font(.appBody).foregroundStyle(.appInk)
                            .multilineTextAlignment(.center)
                    }
                    if let rating = info.rating {
                        StarRating(rating: rating)
                    }
                }
                HStack(spacing: 12) {
                    PillButton("한 번 더") { onAgain() }
                }
            }
            .padding(24)
            .scaleEffect(stamped ? 1 : 1.15)
            .rotationEffect(.degrees(stamped ? 0 : -4))
            .opacity(stamped ? 1 : 0)
            .task {
                withAnimation(.interpolatingSpring(stiffness: 210, damping: 14)) { stamped = true }
            }
        }
        .sensoryFeedback(.success, trigger: cutout.id)
    }
}
