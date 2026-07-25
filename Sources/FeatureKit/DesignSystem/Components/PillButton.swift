import SwiftUI

public struct PillButton: View {
    private let title: String
    private let enabled: Bool
    private let action: () -> Void

    public init(_ title: String, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(enabled ? Color.appCherry : Color.appMuted.opacity(0.55))
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(Color.appCard, lineWidth: 3).padding(2)
                }
        }
        .buttonStyle(KitschPressStyle())
        .disabled(!enabled)
        .softShadow()
    }
}

#Preview {
    VStack {
        PillButton("다이어리에 저장") {}
        PillButton("비활성", enabled: false) {}
    }
    .padding().background(Color.appMilk)
}
