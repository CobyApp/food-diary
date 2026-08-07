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
    let themes: Headline
    let map: Headline
    let game: Headline
    let group: Headline
    let achievements: Headline
    let recap: Headline
    let recapCaption: String
    let sampleTags: [String]
    /// Place label on the map card.
    let mapPlace: String
    /// The line under the world-cup round.
    let gamePrompt: String
    /// Place labels on the two world-cup contenders.
    let gamePlaces: [String]
    /// Three short chips describing how the group vote works.
    let groupRules: [String]
    let votingLabel: String
    let streakLabel: String

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
        themes: .init(title: "보드 배경도\n골라서 꾸며요", subtitle: "네 가지 배경으로 분위기를 바꿔요"),
        map: .init(title: "어디서 먹었는지\n지도에 남아요", subtitle: "핀을 누르면 그날의 한 그릇"),
        game: .init(title: "뭐 먹지 싶을 때\n월드컵으로 골라요", subtitle: "고르다 보면 오늘의 우승 메뉴가 나와요"),
        group: .init(title: "여럿이 모여\n같이 정해요", subtitle: "5초 안에 투표, 많이 받은 쪽이 이겨요"),
        achievements: .init(title: "먹은 만큼\n도감이 채워져요", subtitle: "연속 기록과 배지를 모아요"),
        recap: .init(title: "한 장으로\n자랑해요", subtitle: "스토리에 딱 맞는 카드로 공유"),
        recapCaption: "이번에도 잘 먹었다",
        sampleTags: ["라멘", "매운맛", "재방문"],
        mapPlace: "하카타 라멘집",
        gamePrompt: "더 먹고 싶은 쪽을 골라요",
        gamePlaces: ["하카타 라멘집", "동네 분식집"],
        groupRules: ["함께하기", "5초 투표", "다수결"],
        votingLabel: "투표 시작",
        streakLabel: "12일 연속 기록"
    )

    static let english = StoreCopy(
        board: .init(title: "Collect your meals\nas stickers", subtitle: "Every dish lands on a board of your own"),
        cutout: .init(title: "Cut the food\nout of the photo", subtitle: "Many at once, each on its own"),
        tags: .init(title: "Tag every dish\nyour way", subtitle: "Make the tags, rename them, drop them"),
        drawer: .init(title: "Arrange the board\nfrom your drawer", subtitle: "Put a sticker out or take it back, any time"),
        themes: .init(title: "Dress the board\nhowever you like", subtitle: "Four backdrops, four moods"),
        map: .init(title: "See where\nyou ate it", subtitle: "Tap a pin, get that day's bowl"),
        game: .init(title: "Can't decide?\nRun a bracket", subtitle: "Keep picking until one dish wins"),
        group: .init(title: "Settle it\ntogether", subtitle: "Five seconds to vote, the majority wins"),
        achievements: .init(title: "Fill the book\nas you eat", subtitle: "Streaks to keep, badges to collect"),
        recap: .init(title: "Show it off\nin one card", subtitle: "Sized for your story, ready to share"),
        recapCaption: "Ate well again",
        sampleTags: ["Ramen", "Spicy", "Going back"],
        mapPlace: "Hakata Ramen",
        gamePrompt: "Pick the one you'd rather eat",
        gamePlaces: ["Hakata Ramen", "Corner diner"],
        groupRules: ["Play together", "5-second vote", "Majority wins"],
        votingLabel: "Start the vote",
        streakLabel: "12-day streak"
    )

    static let japanese = StoreCopy(
        board: .init(title: "ごはんを\nステッカーで集める", subtitle: "食べた一品が自分のボードにたまります"),
        cutout: .init(title: "写真から\nごはんだけ切り抜き", subtitle: "何枚でも、一品ずつ別々に"),
        tags: .init(title: "一品ごとに\n自分のタグを", subtitle: "タグは自分で作って、直せます"),
        drawer: .init(title: "引き出しから選んで\nボードを飾る", subtitle: "出すのも戻すのも、いつでも自由"),
        themes: .init(title: "ボードの背景も\n選んで飾る", subtitle: "4つの背景で気分を変える"),
        map: .init(title: "どこで食べたか\n地図に残る", subtitle: "ピンを押せば、その日の一杯"),
        game: .init(title: "何を食べるか\nワールドカップで決める", subtitle: "選んでいくと今日の優勝メニュー"),
        group: .init(title: "みんなで集まって\nいっしょに決める", subtitle: "5秒で投票、多いほうが勝ち"),
        achievements: .init(title: "食べるほど\n図鑑がうまる", subtitle: "連続記録とバッジを集める"),
        recap: .init(title: "一枚にまとめて\n自慢する", subtitle: "ストーリーにぴったりのカード"),
        recapCaption: "今回もおいしかった",
        sampleTags: ["ラーメン", "辛い", "また行く"],
        mapPlace: "博多ラーメン",
        gamePrompt: "食べたいほうを選んでね",
        gamePlaces: ["博多ラーメン", "近所の食堂"],
        groupRules: ["いっしょに", "5秒投票", "多数決"],
        votingLabel: "投票をはじめる",
        streakLabel: "12日連続の記録"
    )

    static let chinese = StoreCopy(
        board: .init(title: "把每一餐\n收成贴纸", subtitle: "吃过的菜都落在你自己的板上"),
        cutout: .init(title: "从照片里\n只抠出食物", subtitle: "一次多张，每道菜各自独立"),
        tags: .init(title: "给每道菜\n贴上自己的标签", subtitle: "标签自己建、自己改"),
        drawer: .init(title: "从抽屉里挑\n布置这块板", subtitle: "放上去、收回来，随时都行"),
        themes: .init(title: "背景也能挑\n把板子布置好", subtitle: "四种背景，四种心情"),
        map: .init(title: "在哪儿吃的\n地图都记着", subtitle: "点一下图钉，就是那天那碗"),
        game: .init(title: "不知道吃什么\n就开一场淘汰赛", subtitle: "一路选下去，今天的冠军就出来了"),
        group: .init(title: "一群人聚起来\n一起定", subtitle: "五秒投票，票多的那份赢"),
        achievements: .init(title: "吃得越多\n图鉴越满", subtitle: "连续记录和徽章都能收"),
        recap: .init(title: "一张卡片\n就够炫耀", subtitle: "尺寸正好，直接发限时动态"),
        recapCaption: "这次也吃得很好",
        sampleTags: ["拉面", "辣", "还要再来"],
        mapPlace: "博多拉面",
        gamePrompt: "选你更想吃的那一份",
        gamePlaces: ["博多拉面", "街角小馆"],
        groupRules: ["一起玩", "5秒投票", "多数决"],
        votingLabel: "开始投票",
        streakLabel: "连续 12 天"
    )
}

// MARK: - Sample food

/// Sample food for the store shots, already wearing the app's sticker outline.
///
/// The outline is not baked into a saved cutout: the app stores the plain PNG and
/// `CutoutImageLoader` draws the white border when it displays one. Passing a raw
/// image straight to `CutoutImage(image:)` skips that loader, which is why an
/// earlier pass produced borderless food. These go through the loader, so the
/// screenshots show what the app shows.
///
/// Real cutouts come from `fastlane/screenshots/source/*.png` —
/// `Scripts/make-cutouts.swift` writes them from photos. Drawn shapes stand in
/// only when that folder is empty.
struct StoreSampleFood: Identifiable {
    let id = UUID()
    let image: UIImage

    static func load() async -> [StoreSampleFood] {
        let pngs = sourcePNGs() ?? drawnPNGs()
        var foods: [StoreSampleFood] = []
        for (index, data) in pngs.enumerated() {
            // The app's own loader, so the border matches the app exactly.
            guard let outlined = await CutoutImageLoader.shared.image(
                data: data,
                cacheKey: "store-sample-\(index)",
                maxPixelDimension: 720
            ) else { continue }
            foods.append(StoreSampleFood(image: outlined))
        }
        return foods
    }

    private static func sourcePNGs() -> [Data]? {
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
        let data = names.sorted()
            .filter { $0.lowercased().hasSuffix(".png") }
            .compactMap { try? Data(contentsOf: folder.appendingPathComponent($0)) }
        return data.isEmpty ? nil : data
    }

    private static func drawnPNGs() -> [Data] {
        [
            ("takeoutbag.and.cup.and.straw.fill", UIColor(Color.appCherry)),
            ("birthday.cake.fill", UIColor(Color.appPinkInk)),
            ("cup.and.saucer.fill", UIColor(Color.appChocolate)),
            ("carrot.fill", UIColor(Color.appButterInk)),
            ("fish.fill", UIColor(Color.appBlueInk)),
            ("laurel.leading", UIColor(Color.appPinkInk)),
        ].compactMap { symbol, tint in
            symbolImage(symbol, tint: tint)?.pngData()
        }
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
