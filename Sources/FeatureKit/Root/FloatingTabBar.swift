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
            item(.collection, systemImage: "square.grid.2x2", title: "컬렉션")
            item(.capture, systemImage: "plus", title: "담기")
            item(.game, systemImage: "dice", title: "뭐먹지")
            item(.map, systemImage: "map", title: "지도")
        }
        .padding(7)
        .background(Color.appCard)
        .clipShape(Capsule())
        .overlay { Capsule().stroke(Color.appPinkInk.opacity(0.24), lineWidth: 1.5) }
        .softShadow()
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
        .frame(maxWidth: 560)
    }

    private func item(_ tab: RootFeature.Tab, systemImage: String, title: String) -> some View {
        let active = selected == tab
        return Button { onSelect(tab) } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .fontWeight(.black)
                    .symbolEffect(.bounce, value: active)
                Text(L10n.text(title))
            }
            .font(.appCaption)
            .minimumScaleFactor(0.78)
            .lineLimit(1)
            .foregroundStyle(active ? Color.white : Color.appInk)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(active ? Color.appCherry : Color.appCard)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(
                    active ? Color.appCard : Color.appPinkInk.opacity(0.18),
                    lineWidth: active ? 2.5 : 1
                )
            }
            .offset(y: active ? -2 : 0)
        }
        .buttonStyle(KitschPressStyle())
    }
}
