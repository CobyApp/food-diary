import SwiftUI

/// Top bar for a screen that covers the app rather than being pushed or
/// presented as a sheet.
///
/// Sheets get their title and 닫기 from the navigation toolbar. A full-screen
/// cover has no navigation bar to hang them on, and wrapping one in a
/// `NavigationStack` just to borrow the bar collides with the content's own
/// header. This is the same arrangement drawn by hand: title in the middle,
/// 닫기 trailing.
public struct CoverBar: View {
    private let title: String
    private let onClose: () -> Void

    public init(_ title: String, onClose: @escaping () -> Void) {
        self.title = title
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Text(L10n.text(title))
                .font(.appSection)
                .foregroundStyle(.appInk)

            HStack {
                Spacer()
                Button("닫기", action: onClose)
                    .font(.appSection)
                    .foregroundStyle(.appPinkInk)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}
