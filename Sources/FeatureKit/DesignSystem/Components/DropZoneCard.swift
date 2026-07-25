import SwiftUI

public struct DropZoneCard<Content: View>: View {
    private let label: Content
    public init(@ViewBuilder label: () -> Content) { self.label = label() }

    public var body: some View {
        label
            .font(.appSection)
            .foregroundStyle(.appChocolate)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Color.appButter.opacity(0.52))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.dropZone, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.dropZone, style: .continuous)
                    .strokeBorder(Color.appCherry.opacity(0.65), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            )
            .overlay(alignment: .top) { WashiTape(.appPink).offset(y: -8) }
            .softShadow()
    }
}
