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
            .softShadow()
    }
}

#Preview {
    HStack {
        StickerTile(tint: .pink) { Text("🍜").font(.system(size: 30)) }
        StickerTile(tint: .blue) { Text("🍰").font(.system(size: 30)) }
    }
    .padding().background(Color.appMilk)
}
