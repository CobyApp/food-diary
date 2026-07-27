import SwiftUI
import Models

struct ResultCard: View {
    let cutout: CutoutSnapshot
    let info: GameResultInfo?
    let onAgain: () -> Void
    let onClose: () -> Void

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
                    if !info.memo.isEmpty {
                        Text("\u{201C}\(info.memo)\u{201D}")
                            .font(.appBody).foregroundStyle(.appInk)
                            .multilineTextAlignment(.center)
                    }
                    if let rating = info.rating {
                        StarRating(rating: rating)
                    }
                }
                HStack(spacing: 12) {
                    PillButton("한 번 더") { onAgain() }
                    OutlineButton("닫기") { onClose() }
                }
            }
            .padding(24)
        }
        .sensoryFeedback(.success, trigger: cutout.id)
    }
}
