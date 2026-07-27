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
            .padding(14)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
            .shadow(color: .white.opacity(0.9), radius: 2, x: 0, y: 1)
            .shadow(color: tint.color.opacity(0.48), radius: 11, x: 0, y: 6)
            .shadow(color: Color.appChocolate.opacity(0.2), radius: 4, x: 0, y: 4)
    }
}

#Preview {
    HStack {
        StickerTile(tint: .pink) { Image(systemName: "takeoutbag.and.cup.and.straw.fill") }
        StickerTile(tint: .blue) { Image(systemName: "birthday.cake.fill") }
    }
    .padding().background(Color.appMilk)
}
