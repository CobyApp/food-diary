import SwiftUI

public struct SoftCard<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .softShadow()
    }
}

#Preview {
    SoftCard { Text("존맛탱 🥹").font(.appBody).foregroundStyle(Color.appInk) }
        .padding().background(Color.appMilk)
}
