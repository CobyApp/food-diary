import SwiftUI
import Models

struct ResultCard: View {
    let cutout: CutoutSnapshot
    let place: String?
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
                Text(place ?? L10n.text("오늘의 한 끼"))
                    .font(.appDisplay).foregroundStyle(.appChocolate)
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    PillButton("한 번 더") { onAgain() }
                    Button { onClose() } label: {
                        Text("닫기").font(.appSection).foregroundStyle(.appMuted)
                            .padding(.vertical, 14).padding(.horizontal, 22)
                            .background(Color.appCard).clipShape(Capsule()).softShadow()
                    }
                    .buttonStyle(KitschPressStyle())
                }
            }
            .padding(24)
        }
        .sensoryFeedback(.success, trigger: cutout.id)
    }
}
