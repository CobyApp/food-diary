import SwiftUI

public struct StickerTile<Content: View>: View {
    private let tint: StickerTint
    private let content: Content

    public init(tint: StickerTint = .plain, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    public var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(tint.color)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous)
                    .stroke(Color.appCard, lineWidth: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous)
                    .stroke(Color.appChocolate.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .padding(5)
            }
            .softShadow()
    }
}

#Preview {
    HStack {
        StickerTile(tint: .pink) { Image(systemName: "takeoutbag.and.cup.and.straw.fill") }
        StickerTile(tint: .blue) { Image(systemName: "birthday.cake.fill") }
    }
    .padding().background(Color.appMilk)
}
