import SwiftUI

public struct KitschLoadingView: View {
    private let title: String
    private let messages: [String]
    private let compact: Bool

    @State private var isAnimating = false
    @State private var messageIndex = 0

    public init(
        _ title: String = "맛있는 순간을 준비하는 중",
        messages: [String] = [],
        compact: Bool = false
    ) {
        self.title = title
        self.messages = messages
        self.compact = compact
    }

    public var body: some View {
        VStack(spacing: compact ? 9 : 14) {
            ZStack {
                Circle()
                    .stroke(Color.appPink.opacity(0.28), lineWidth: 8)
                    .frame(width: compact ? 52 : 76, height: compact ? 52 : 76)
                    .scaleEffect(isAnimating ? 1.08 : 0.88)
                KitschIcon(
                    "fork.knife",
                    tint: .appChocolate,
                    background: .appButter,
                    size: compact ? 42 : 58
                )
                .rotationEffect(.degrees(isAnimating ? 4 : -4))
            }

            VStack(spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(compact ? .appSection : .appTitle)
                    .foregroundStyle(.appInk)
                    .multilineTextAlignment(.center)
                if !messages.isEmpty {
                    Text(LocalizedStringKey(messages[messageIndex % messages.count]))
                        .font(.appCaption)
                        .foregroundStyle(.appMuted)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .id(messageIndex)
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill([Color.appCherry, .appBlue, .appLavender][index])
                        .frame(width: 7, height: 7)
                        .offset(y: isAnimating == index.isMultiple(of: 2) ? -3 : 3)
                }
            }
        }
        .padding(compact ? 14 : 24)
        .frame(maxWidth: .infinity)
        .background(Color.appCard.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.appChocolate.opacity(0.12), lineWidth: 1.5)
        }
        .softShadow()
        .task {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            guard !messages.isEmpty else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1300))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
