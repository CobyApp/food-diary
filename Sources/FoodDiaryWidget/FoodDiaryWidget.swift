import Models
import ImageIO
import SwiftUI
import WidgetKit

private enum WidgetL10n {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: .current, arguments: arguments)
    }
}

private enum SharedWidgetData {
    static let appGroup = "group.com.coby.food.dairy"
    static let snapshotKey = "foodieDiary.widgetSnapshot"

    static func load() -> (WidgetSnapshot?, UIImage?) {
        let defaults = UserDefaults(suiteName: appGroup)
        let snapshot = defaults?
            .data(forKey: snapshotKey)
            .flatMap { try? JSONDecoder().decode(WidgetSnapshot.self, from: $0) }

        let image = snapshot?.imageFileName.flatMap { fileName in
            FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
                .flatMap {
                    try? Data(
                        contentsOf: $0.appendingPathComponent(fileName),
                        options: [.mappedIfSafe]
                    )
                }
                .flatMap(Self.downsample)
        }
        return (snapshot, image)
    }

    private static func downsample(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 512,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            .map(UIImage.init(cgImage:))
    }
}

private struct CutoutEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let image: UIImage?
}

private struct CutoutProvider: TimelineProvider {
    func placeholder(in context: Context) -> CutoutEntry {
        CutoutEntry(
            date: Date(),
            snapshot: WidgetSnapshot(
                updatedAt: Date(),
                title: WidgetL10n.text("오늘의 한 끼"),
                subtitle: WidgetL10n.text("맛있는 순간을 모아봐요"),
                decoration: "sparkle",
                streak: 3,
                imageFileName: nil
            ),
            image: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CutoutEntry) -> Void) {
        let value = SharedWidgetData.load()
        completion(CutoutEntry(date: Date(), snapshot: value.0, image: value.1))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CutoutEntry>) -> Void) {
        let value = SharedWidgetData.load()
        let entry = CutoutEntry(date: Date(), snapshot: value.0, image: value.1)
        let refresh = Calendar.current.date(byAdding: .hour, value: 6, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

private struct CutoutWidgetView: View {
    let entry: CutoutEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            ZStack {
                Color(red: 0.99, green: 0.97, blue: 0.95)
                VStack(spacing: 6) {
                    HStack {
                        Label(WidgetL10n.format("widget.streak.days", snapshot.streak), systemImage: "flame.fill")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(Color(red: 0.72, green: 0.24, blue: 0.34))
                        Spacer()
                        Image(systemName: decorationSymbol(snapshot.decoration))
                            .font(.caption.bold())
                    }
                    if let image = entry.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 76)
                    } else {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 38, weight: .black))
                            .foregroundStyle(Color(red: 0.72, green: 0.24, blue: 0.34))
                    }
                    Text(snapshot.title)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .lineLimit(1)
                    Text(snapshot.subtitle)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .foregroundStyle(Color(red: 0.29, green: 0.29, blue: 0.34))
                .padding(12)
            }
            .containerBackground(for: .widget) { Color.white }
        } else {
            ZStack {
                Color(red: 0.99, green: 0.97, blue: 0.95)
                VStack(spacing: 8) {
                    Image(systemName: "camera.macro")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(Color(red: 0.72, green: 0.24, blue: 0.34))
                    Text("첫 한 끼를 담아주세요")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
            }
            .containerBackground(for: .widget) { Color.white }
        }
    }

    private func decorationSymbol(_ value: String?) -> String {
        switch value {
        case "heart": return "heart.fill"
        case "star": return "star.fill"
        case "ribbon": return "gift.fill"
        default: return "sparkles"
        }
    }
}

@main
struct FoodDiaryCutoutWidget: Widget {
    let kind = "FoodDiaryCutoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CutoutProvider()) { entry in
            CutoutWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘의 누끼")
        .description("가장 최근에 담은 음식 누끼와 스트릭을 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
