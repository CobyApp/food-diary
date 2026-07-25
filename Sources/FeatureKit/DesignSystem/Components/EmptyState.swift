import SwiftUI

public struct EmptyState: View {
    private let systemImage: String
    private let title: String
    private let subtitle: String

    public init(systemImage: String, title: String, subtitle: String) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 10) {
            KitschIcon(systemImage, tint: .appChocolate, background: .appPink, size: 70)
            Text(LocalizedStringKey(title)).font(.appTitle).foregroundStyle(.appInk)
            Text(LocalizedStringKey(subtitle)).font(.appBody).foregroundStyle(.appMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .padding(.horizontal, 22)
        .background(Color.appCard.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay { RoundedRectangle(cornerRadius: 28).stroke(Color.appChocolate.opacity(0.1)) }
    }
}

#Preview {
    ScreenScaffold(title: "컬렉션") {
        EmptyState(systemImage: "fork.knife", title: "아직 누끼가 없어요",
                   subtitle: "음식 사진을 찍어 첫 누끼를 담아보세요!")
    }
}
