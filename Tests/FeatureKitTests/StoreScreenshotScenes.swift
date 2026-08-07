import SwiftUI
@testable import FeatureKit

// MARK: - Marketing copy

/// Store copy, kept here rather than in Localizable.strings: it is written for the
/// store listing, never shown in the app, and shipping it would put unused strings
/// in the bundle.
struct StoreCopy {
    let board: Headline
    let cutout: Headline
    let tags: Headline
    let drawer: Headline
    let recap: Headline
    let recapCaption: String
    let sampleTags: [String]

    struct Headline {
        let title: String
        let subtitle: String
    }

    static func forLanguage(_ language: String) -> StoreCopy {
        switch language {
        case "en": return english
        case "ja": return japanese
        case "zh-Hans": return chinese
        default: return korean
        }
    }

    static let korean = StoreCopy(
        board: .init(title: "내 밥상을\n스티커로 모아요", subtitle: "먹은 음식이 나만의 보드에 쌓여요"),
        cutout: .init(title: "사진에서\n음식만 오려내요", subtitle: "여러 장을 한 번에, 음식마다 따로"),
        tags: .init(title: "음식마다\n내 태그를 붙여요", subtitle: "태그는 직접 만들고 고쳐요"),
        drawer: .init(title: "서랍에서 골라\n보드를 꾸며요", subtitle: "올리고 내리는 건 언제든 자유롭게"),
        recap: .init(title: "한 장으로\n자랑해요", subtitle: "스토리에 딱 맞는 카드로 공유"),
        recapCaption: "이번에도 잘 먹었다",
        sampleTags: ["라멘", "매운맛", "재방문"]
    )

    static let english = StoreCopy(
        board: .init(title: "Collect your meals\nas stickers", subtitle: "Every dish lands on a board of your own"),
        cutout: .init(title: "Cut the food\nout of the photo", subtitle: "Many at once, each on its own"),
        tags: .init(title: "Tag every dish\nyour way", subtitle: "Make the tags, rename them, drop them"),
        drawer: .init(title: "Arrange the board\nfrom your drawer", subtitle: "Put a sticker out or take it back, any time"),
        recap: .init(title: "Show it off\nin one card", subtitle: "Sized for your story, ready to share"),
        recapCaption: "Ate well again",
        sampleTags: ["Ramen", "Spicy", "Going back"]
    )

    static let japanese = StoreCopy(
        board: .init(title: "ごはんを\nステッカーで集める", subtitle: "食べた一品が自分のボードにたまります"),
        cutout: .init(title: "写真から\nごはんだけ切り抜き", subtitle: "何枚でも、一品ずつ別々に"),
        tags: .init(title: "一品ごとに\n自分のタグを", subtitle: "タグは自分で作って、直せます"),
        drawer: .init(title: "引き出しから選んで\nボードを飾る", subtitle: "出すのも戻すのも、いつでも自由"),
        recap: .init(title: "一枚にまとめて\n自慢する", subtitle: "ストーリーにぴったりのカード"),
        recapCaption: "今回もおいしかった",
        sampleTags: ["ラーメン", "辛い", "また行く"]
    )

    static let chinese = StoreCopy(
        board: .init(title: "把每一餐\n收成贴纸", subtitle: "吃过的菜都落在你自己的板上"),
        cutout: .init(title: "从照片里\n只抠出食物", subtitle: "一次多张，每道菜各自独立"),
        tags: .init(title: "给每道菜\n贴上自己的标签", subtitle: "标签自己建、自己改"),
        drawer: .init(title: "从抽屉里挑\n布置这块板", subtitle: "放上去、收回来，随时都行"),
        recap: .init(title: "一张卡片\n就够炫耀", subtitle: "尺寸正好，直接发限时动态"),
        recapCaption: "这次也吃得很好",
        sampleTags: ["拉面", "辣", "还要再来"]
    )
}

// MARK: - Sample food

/// Stand-in cutouts, drawn rather than photographed.
///
/// Drop real cutout PNGs into `fastlane/screenshots/source/` (any names, sorted)
/// and they are used instead — the store should show real food where possible.
struct StoreSampleFood: Identifiable {
    let id = UUID()
    let image: UIImage

    static let all: [StoreSampleFood] = {
        if let real = realCutouts(), real.count >= 3 { return real }
        return drawn
    }()

    private static func realCutouts() -> [StoreSampleFood]? {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        let folder = url
            .appendingPathComponent("fastlane")
            .appendingPathComponent("screenshots")
            .appendingPathComponent("source")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path)
        else { return nil }
        let images = names.sorted()
            .filter { $0.lowercased().hasSuffix(".png") }
            .compactMap { UIImage(contentsOfFile: folder.appendingPathComponent($0).path) }
        return images.isEmpty ? nil : images.map { StoreSampleFood(image: $0) }
    }

    private static let drawn: [StoreSampleFood] = [
        ("takeoutbag.and.cup.and.straw.fill", UIColor(Color.appCherry)),
        ("birthday.cake.fill", UIColor(Color.appPinkInk)),
        ("cup.and.saucer.fill", UIColor(Color.appChocolate)),
        ("carrot.fill", UIColor(Color.appButterInk)),
        ("fish.fill", UIColor(Color.appBlueInk)),
        ("laurel.leading", UIColor(Color.appPinkInk)),
    ].compactMap { symbol, tint in
        symbolImage(symbol, tint: tint).map(StoreSampleFood.init(image:))
    }

    private static func symbolImage(_ name: String, tint: UIColor) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 260, weight: .bold)
        guard let symbol = UIImage(systemName: name, withConfiguration: configuration) else {
            return nil
        }
        let size = CGSize(width: 320, height: 320)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let tinted = symbol.withTintColor(tint, renderingMode: .alwaysOriginal)
            let fitted = CGRect(
                x: (size.width - symbol.size.width) / 2,
                y: (size.height - symbol.size.height) / 2,
                width: symbol.size.width,
                height: symbol.size.height
            )
            tinted.draw(in: fitted)
        }
    }
}
