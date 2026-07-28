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
        }
        .buttonStyle(KitschFilledButtonStyle())
        .disabled(!enabled)
    }
}

public struct OutlineButton: View {
    private let title: String
    private let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
        }
        .buttonStyle(KitschOutlineButtonStyle())
    }
}

#Preview {
    VStack {
        PillButton("다이어리에 저장") {}
        PillButton("비활성", enabled: false) {}
        OutlineButton("닫기") {}
    }
    .padding().background(Color.appMilk)
}
