import SwiftUI

public struct ProfileAvatarStyle: Equatable, Identifiable {
    public let id: String
    public let symbol: String
    public let title: String
    public let color: Color

    public static let all: [ProfileAvatarStyle] = [
        .init(id: "heart", symbol: "heart.fill", title: "러블리", color: .appPink),
        .init(id: "ribbon", symbol: "gift.fill", title: "리본", color: .appLavender),
        .init(id: "cherry", symbol: "circle.grid.cross.fill", title: "체리", color: .appCherry),
        .init(id: "flower", symbol: "camera.macro", title: "플라워", color: .appButter),
        .init(id: "star", symbol: "star.fill", title: "스타", color: .appBlue),
        .init(id: "cake", symbol: "birthday.cake.fill", title: "케이크", color: .appPink),
    ]

    public static func resolve(_ value: String) -> ProfileAvatarStyle {
        if let style = all.first(where: { $0.id == value }) { return style }
        switch value {
        case "\u{1F35C}": return all[1]
        case "\u{1F355}": return all[2]
        case "\u{1F950}": return all[3]
        case "\u{1F370}": return all[5]
        default: return all[0]
        }
    }
}

public struct ProfileAvatarView: View {
    private let value: String
    private let size: CGFloat

    public init(_ value: String, size: CGFloat = 76) {
        self.value = value
        self.size = size
    }

    public var body: some View {
        let style = ProfileAvatarStyle.resolve(value)
        ZStack {
            Circle().fill(style.color.opacity(0.28))
            Circle()
                .stroke(Color.appChocolate.opacity(0.16), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .padding(7)
            Image(systemName: style.symbol)
                .font(.system(size: size * 0.38, weight: .black))
                .foregroundStyle(Color.appChocolate)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .top) { WashiTape(.appButter).offset(y: -7) }
        .softShadow()
    }
}
