import SwiftUI

public struct PaperBackground: View {
    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.appMilk
                Image("StickerPaper")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .opacity(0.22)
                    .blendMode(.multiply)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

public struct KitschSparkle: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.midX + rect.width * 0.06, y: rect.midY - rect.height * 0.06),
            control2: CGPoint(x: rect.midX + rect.width * 0.06, y: rect.midY - rect.height * 0.06)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.midX + rect.width * 0.06, y: rect.midY + rect.height * 0.06),
            control2: CGPoint(x: rect.midX + rect.width * 0.06, y: rect.midY + rect.height * 0.06)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.midY),
            control1: CGPoint(x: rect.midX - rect.width * 0.06, y: rect.midY + rect.height * 0.06),
            control2: CGPoint(x: rect.midX - rect.width * 0.06, y: rect.midY + rect.height * 0.06)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.midX - rect.width * 0.06, y: rect.midY - rect.height * 0.06),
            control2: CGPoint(x: rect.midX - rect.width * 0.06, y: rect.midY - rect.height * 0.06)
        )
        return path
    }
}

public struct KitschIcon: View {
    private let systemName: String
    private let tint: Color
    private let background: Color
    private let size: CGFloat

    public init(
        _ systemName: String,
        tint: Color = .appChocolate,
        background: Color = .appPink,
        size: CGFloat = 42
    ) {
        self.systemName = systemName
        self.tint = tint
        self.background = background
        self.size = size
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .black))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .stroke(Color.appCard, lineWidth: 3)
            }
            .rotationEffect(.degrees(-3))
            .softShadow()
    }
}

public struct WashiTape: View {
    private let color: Color

    public init(_ color: Color = .appButter) {
        self.color = color
    }

    public var body: some View {
        Rectangle()
            .fill(color.opacity(0.72))
            .frame(width: 58, height: 16)
            .overlay {
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle().fill(Color.appCard.opacity(0.55)).frame(width: 3, height: 3)
                    }
                }
            }
            .rotationEffect(.degrees(-5))
    }
}

public struct ConfettiBurst: View {
    private let colors: [Color] = [.appCherry, .appBlue, .appButter, .appLavender]

    public init() {}

    public var body: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { index in
                Capsule()
                    .fill(colors[index % colors.count])
                    .frame(width: 5, height: 14)
                    .offset(y: -125)
                    .rotationEffect(.degrees(Double(index) * 20))
            }
        }
        .allowsHitTesting(false)
    }
}
