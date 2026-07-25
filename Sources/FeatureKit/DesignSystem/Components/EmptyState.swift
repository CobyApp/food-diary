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
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(Color.appBlue)
            Text(title).font(.appTitle).foregroundStyle(.appInk)
            Text(subtitle).font(.appBody).foregroundStyle(.appMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

#Preview {
    ScreenScaffold(title: "컬렉션") {
        EmptyState(systemImage: "fork.knife", title: "아직 누끼가 없어요",
                   subtitle: "음식 사진을 찍어 첫 누끼를 담아보세요!")
    }
}
