import SwiftUI

public struct SoftCard<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(Color.appPinkInk.opacity(0.18), lineWidth: 1.5)
            }
            .softShadow()
    }
}

#Preview {
    SoftCard { Text("오늘의 맛있는 기록").font(.appBody).foregroundStyle(Color.appInk) }
        .padding().background(Color.appMilk)
}
