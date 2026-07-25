import SwiftUI
import Models

struct ResultCard: View {
    let cutout: CutoutSnapshot
    let place: String?
    let onAgain: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("오늘은 여기! 🍜").font(.appTitle).foregroundStyle(.appInk)
            StickerTile(tint: .pink) { CutoutImage(fileName: cutout.fileName) }
                .frame(width: 210, height: 210)
                .transition(.scale.combined(with: .opacity))
            Text(place ?? cutout.label ?? "맛있는 거")
                .font(.appDisplay).foregroundStyle(.appBlueInk)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                PillButton("다시 뽑기") { onAgain() }
                Button { onClose() } label: {
                    Text("닫기").font(.appSection).foregroundStyle(.appMuted)
                        .padding(.vertical, 14).padding(.horizontal, 22)
                        .background(Color.appCard).clipShape(Capsule()).softShadow()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
    }
}
