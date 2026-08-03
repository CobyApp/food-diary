import SwiftUI

/// An in-app confirmation, styled like the rest of the app rather than borrowed
/// from the system.
///
/// A system dialog gives no room to explain a difference that matters — here,
/// that deleting a food is not the same as taking it off the board — and puts its
/// cancel wherever the platform likes. This states the difference and gives the
/// two choices equal, obvious weight.
public struct ConfirmCard: View {
    private let title: String
    private let message: String
    private let confirmTitle: String
    private let cancelTitle: String
    private let onConfirm: () -> Void
    private let onCancel: () -> Void

    public init(
        title: String,
        message: String,
        confirmTitle: String,
        cancelTitle: String = "취소",
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            // Tapping the dimmed backdrop is the same as cancelling.
            Color.appChocolate.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 14) {
                KitschIcon("trash", tint: .appPinkInk, background: .appPink, size: 52)

                VStack(spacing: 6) {
                    Text(L10n.text(title))
                        .font(.appTitle)
                        .foregroundStyle(.appInk)
                        .multilineTextAlignment(.center)
                    Text(L10n.text(message))
                        .font(.appCaption)
                        .foregroundStyle(.appMuted)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 8) {
                    Button(action: onConfirm) {
                        Text(L10n.text(confirmTitle))
                    }
                    .buttonStyle(
                        KitschFilledButtonStyle(color: .appPinkInk, fullWidth: true, verticalPadding: 13)
                    )

                    Button(action: onCancel) {
                        Text(L10n.text(cancelTitle))
                            .font(.appSection)
                            .foregroundStyle(.appInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appCard, in: Capsule())
                            .overlay {
                                Capsule().stroke(Color.appChocolate.opacity(0.18), lineWidth: 1.5)
                            }
                    }
                    .buttonStyle(KitschPressStyle())
                }
            }
            .padding(20)
            .frame(maxWidth: 300)
            .background(Color.appMilk, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.appPinkInk.opacity(0.22), lineWidth: 2)
            }
            .softShadow()
            .padding(.horizontal, 28)
        }
    }
}
