import SwiftUI

public struct FloatingTabBar: View {
    private let selected: RootFeature.Tab
    private let onSelect: (RootFeature.Tab) -> Void

    public init(selected: RootFeature.Tab, onSelect: @escaping (RootFeature.Tab) -> Void) {
        self.selected = selected
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 4) {
            item(.collection, systemImage: "square.grid.2x2.fill", title: "컬렉션")
            item(.capture, systemImage: "plus.circle.fill", title: "담기")
        }
        .padding(6)
        .background(Color.appCard)
        .clipShape(Capsule())
        .softShadow()
        .padding(.horizontal, 60)
        .padding(.bottom, 6)
    }

    private func item(_ tab: RootFeature.Tab, systemImage: String, title: String) -> some View {
        let active = selected == tab
        return Button { onSelect(tab) } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.appCaption)
            .foregroundStyle(active ? Color.appBlueInk : Color.appMuted)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(active ? Color.appTileBlue : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
