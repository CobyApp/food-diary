import SwiftUI

public struct PastelChip: View {
    public enum Tone { case blue, pink, butter }

    private let text: String
    private let symbol: String?
    private let tone: Tone

    public init(_ text: String, symbol: String? = nil, tone: Tone = .blue) {
        self.text = text
        self.symbol = symbol
        self.tone = tone
    }

    private var background: Color {
        switch tone {
        case .blue: return .appTileBlue
        case .pink: return .appTilePink
        case .butter: return .appTileButter
        }
    }
    private var foreground: Color {
        switch tone {
        case .blue: return .appBlueInk
        case .pink: return .appPinkInk
        case .butter: return .appButterInk
        }
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).fontWeight(.black) }
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.78)
        }
        .font(.appCaption)
        .foregroundStyle(foreground)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(background)
        .clipShape(Capsule())
        .overlay { Capsule().stroke(foreground.opacity(0.32), lineWidth: 1.5) }
    }
}

#Preview {
    HStack {
        PastelChip("라멘집", symbol: "mappin", tone: .blue)
        PastelChip("7.24 목", symbol: "calendar", tone: .pink)
        PastelChip("메모", tone: .butter)
    }
    .padding().background(Color.appMilk)
}
