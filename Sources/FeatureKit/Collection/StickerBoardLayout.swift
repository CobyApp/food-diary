import CoreGraphics
import Foundation

struct StickerBoardPlacement: Codable, Equatable {
    var xFraction: Double
    var y: Double
}

enum FreeStickerBoardLayout {
    static let columns = 3
    static let minimumHeight: CGFloat = 340
    static let horizontalInset: CGFloat = 8
    static let verticalInset: CGFloat = 18

    static func itemSide(width: CGFloat) -> CGFloat {
        min(max((width - 24) / CGFloat(columns), 84), 118)
    }

    static func defaultPoint(index: Int, width: CGFloat) -> CGPoint {
        let side = itemSide(width: width)
        let columnWidth = width / CGFloat(columns)
        let column = index % columns
        let row = index / columns
        return CGPoint(
            x: columnWidth * (CGFloat(column) + 0.5),
            y: verticalInset + side / 2 + CGFloat(row) * (side * 0.92)
        )
    }

    static func boardHeight(count: Int, width: CGFloat, placements: [StickerBoardPlacement]) -> CGFloat {
        let side = itemSide(width: width)
        let lastDefaultY = count > 0 ? defaultPoint(index: count - 1, width: width).y : 0
        let lastPlacedY = CGFloat(placements.map(\.y).max() ?? 0)
        return max(minimumHeight, max(lastDefaultY, lastPlacedY) + side / 2 + verticalInset)
    }

    static func point(
        for placement: StickerBoardPlacement?,
        index: Int,
        width: CGFloat,
        height: CGFloat
    ) -> CGPoint {
        guard let placement else { return defaultPoint(index: index, width: width) }
        return clamped(
            CGPoint(x: width * CGFloat(placement.xFraction), y: CGFloat(placement.y)),
            width: width,
            height: height
        )
    }

    static func clamped(_ point: CGPoint, width: CGFloat, height: CGFloat) -> CGPoint {
        let halfSide = itemSide(width: width) / 2
        return CGPoint(
            x: min(max(point.x, halfSide + horizontalInset), width - halfSide - horizontalInset),
            y: min(max(point.y, halfSide + verticalInset), height - halfSide - verticalInset)
        )
    }

    static func placement(for point: CGPoint, width: CGFloat, height: CGFloat) -> StickerBoardPlacement {
        let point = clamped(point, width: width, height: height)
        return StickerBoardPlacement(
            xFraction: width > 0 ? Double(point.x / width) : 0.5,
            y: Double(point.y)
        )
    }
}
