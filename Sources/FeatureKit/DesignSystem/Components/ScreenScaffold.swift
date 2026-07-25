import SwiftUI

public struct ScreenScaffold<Content: View>: View {
    private let title: String
    private let doodle: String?
    private let content: Content

    public init(title: String, doodle: String? = "✦", @ViewBuilder content: () -> Content) {
        self.title = title
        self.doodle = doodle
        self.content = content()
    }

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 6) {
                        Text(title).font(.appDisplay).foregroundStyle(.appInk)
                        if let doodle { Text(doodle).font(.appDisplay).foregroundStyle(.appBlue) }
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
