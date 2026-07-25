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
            Text(title)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(enabled ? Color.appBlue : Color.appMuted)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .softShadow()
    }
}

#Preview {
    VStack {
        PillButton("다이어리에 저장 ♡") {}
        PillButton("비활성", enabled: false) {}
    }
    .padding().background(Color.appMilk)
}
