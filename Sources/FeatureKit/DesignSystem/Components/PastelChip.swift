import SwiftUI

public struct PastelChip: View {
    public enum Tone { case blue, pink, butter }

    private let text: String
    private let glyph: String?
    private let tone: Tone

    public init(_ text: String, glyph: String? = nil, tone: Tone = .blue) {
        self.text = text
        self.glyph = glyph
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
            if let glyph { Text(glyph) }
            Text(text)
        }
        .font(.appCaption)
        .foregroundStyle(foreground)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(background)
        .clipShape(Capsule())
    }
}

#Preview {
    HStack {
        PastelChip("라멘집", glyph: "✦", tone: .blue)
        PastelChip("7.24 목", glyph: "📅", tone: .pink)
        PastelChip("메모", tone: .butter)
    }
    .padding().background(Color.appMilk)
}
