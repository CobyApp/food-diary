import SwiftUI

public struct ScreenScaffold<Content: View>: View {
    private let title: String
    private let doodle: String?
    private let content: Content

    public init(title: String, doodle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.doodle = doodle
        self.content = content()
    }

    public var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.text(title).uppercased())
                                .font(.appDisplay)
                                .foregroundStyle(.appInk)
                            Rectangle()
                                .fill(Color.appCherry)
                                .frame(width: 44, height: 4)
                                .clipShape(Capsule())
                        }
                        KitschSparkle()
                            .fill(Color.appBlue)
                            .frame(width: 18, height: 18)
                            .rotationEffect(.degrees(10))
                    }
                    .padding(.top, 8)
                    content
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 96)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
