import SwiftUI

public struct DropZoneCard<Content: View>: View {
    private let label: Content
    public init(@ViewBuilder label: () -> Content) { self.label = label() }

    public var body: some View {
        label
            .font(.appSection)
            .foregroundStyle(.appBlueInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Color.appTileBlue.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.dropZone, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.dropZone, style: .continuous)
                    .strokeBorder(Color.appBlue, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            )
    }
}
