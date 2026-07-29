import ClientKit
import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

public struct RecapExport: Transferable {
    let data: Data

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName("yumkie-food-recap.png")
    }
}

public struct RecapCardView: View {
    let images: [UIImage]
    let mealCount: Int

    public init(images: [UIImage], mealCount: Int) {
        self.images = images
        self.mealCount = mealCount
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("나의 맛있는 기록")
                    .font(.appTitle)
                    .foregroundStyle(.appInk)
                Text(L10n.format("recap.meals.count", mealCount))
                    .font(.appBody)
                    .foregroundStyle(.appMuted)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(images.prefix(9).enumerated()), id: \.offset) { index, image in
                    StickerTile(tint: .rotating(index)) {
                        CutoutImage(image: image)
                    }
                    .frame(height: 82)
                }
            }

            HStack {
                Spacer()
                Text(verbatim: "YUMKIE / WEEKLY")
                    .font(.appCaption)
                    .foregroundStyle(.appMuted)
            }
        }
        .padding(22)
        .frame(width: 320)
        .background {
            ZStack {
                Color.appMilk
                Image("StickerPaper")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.32)
                    .blendMode(.multiply)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.appChocolate.opacity(0.15), lineWidth: 1.5)
        }
        .overlay(alignment: .top) { WashiTape(.appPink).offset(y: -8) }
    }
}

public struct RecapView: View {
    @Bindable var store: StoreOf<RecapFeature>
    @State private var images: [UIImage] = []
    @State private var imageCutoutIDs: [UUID] = []
    @State private var export: RecapExport?
    @AppStorage("collection.freeStickerBoard.v1") private var savedStickerPlacements = ""
    @AppStorage("collection.stickerBoardTheme.v1")
    private var selectedThemeRaw = StickerBoardTheme.strawberryCheck.rawValue

    public init(store: StoreOf<RecapFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                VStack(spacing: 0) {
                    if store.cutouts.isEmpty {
                        EmptyState(
                            systemImage: "film.stack",
                            title: "보드가 비어 있어요",
                            subtitle: "서랍에서 누끼를 올린 뒤 리캡을 만들어보세요!"
                        )
                        .padding(.horizontal, 22)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 14) {
                                card
                                captionEditor
                                if let export {
                                    ShareLink(item: export, preview: SharePreview("나의 푸드 리캡")) {
                                        Label("스토리로 공유하기", systemImage: "square.and.arrow.up")
                                    }
                                    .buttonStyle(KitschFilledButtonStyle())
                                    .padding(.horizontal, 24)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .navigationTitle("푸드 리캡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { store.send(.close) }
                }
            }
        }
        .task { store.send(.onAppear) }
        .task(id: store.caption) {
            guard !images.isEmpty else { return }
            await renderExport()
        }
        .task(id: "\(selectedThemeRaw)|\(savedStickerPlacements)") {
            guard !images.isEmpty else { return }
            await renderExport()
        }
        .task(id: store.cutouts) {
            var loadedImages: [UIImage] = []
            var loadedIDs: [UUID] = []
            for cutout in store.cutouts {
                if let image = await CutoutImageLoader.shared.image(
                    fileName: cutout.fileName,
                    cacheKey: cutout.fileName,
                    maxPixelDimension: 720
                ) {
                    loadedImages.append(image)
                    loadedIDs.append(cutout.id)
                }
            }
            images = loadedImages
            imageCutoutIDs = loadedIDs
            await renderExport()
        }
    }

    private var selectedTheme: StickerBoardTheme {
        StickerBoardTheme(rawValue: selectedThemeRaw) ?? .strawberryCheck
    }

    private var storyBoardPlacements: [StickerBoardPlacement?] {
        guard let data = savedStickerPlacements.data(using: .utf8),
              let placements = try? JSONDecoder().decode(
                [String: StickerBoardPlacement].self,
                from: data
              ) else {
            return Array(repeating: nil, count: images.count)
        }
        return imageCutoutIDs.map { placements[$0.uuidString] }
    }

    /// Preview the exact card that gets shared, scaled down to fit the sheet.
    private var card: some View {
        let scale: CGFloat = 0.72
        return RecapStoryCard(
            images: images,
            mealCount: store.mealCount,
            caption: store.caption,
            theme: selectedTheme,
            boardPlacements: storyBoardPlacements
        )
        .frame(width: RecapStoryCard.size.width, height: RecapStoryCard.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .softShadow()
        .scaleEffect(scale)
        .frame(
            width: RecapStoryCard.size.width * scale,
            height: RecapStoryCard.size.height * scale
        )
    }

    private var captionEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("스토리 한 줄")
                        .font(.appSection)
                        .foregroundStyle(.appInk)
                    Text("AI 초안을 자유롭게 고쳐보세요")
                        .font(.appCaption)
                        .foregroundStyle(.appPinkInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 6)
                Text("\((store.caption ?? "").count)/60")
                    .font(.appCaption)
                    .foregroundStyle(.appMuted)
                    .monospacedDigit()
            }

            TextField(
                "직접 적어주세요",
                text: Binding(
                    get: { store.caption ?? "" },
                    set: { store.send(.captionChanged($0)) }
                ),
                axis: .vertical
            )
            .font(.appBody)
            .foregroundStyle(.appInk)
            .lineLimit(2...3)
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.appCherry.opacity(0.55), lineWidth: 2)
            }
        }
        .padding(14)
        .background(Color.appPink.opacity(0.42), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .topTrailing) {
            StoryEditorBow()
                .frame(width: 34, height: 26)
                .offset(x: -12, y: -9)
        }
        .padding(.horizontal, 20)
    }

    @MainActor
    private func renderExport() async {
        guard !images.isEmpty else {
            export = nil
            return
        }
        // 360x640 pt at scale 3 == 1080x1920 px, the native Story size.
        let renderer = ImageRenderer(content:
            RecapStoryCard(
                images: images,
                mealCount: store.mealCount,
                caption: store.caption,
                theme: selectedTheme,
                    boardPlacements: storyBoardPlacements
            )
            .frame(width: RecapStoryCard.size.width, height: RecapStoryCard.size.height)
        )
        renderer.scale = 3
        export = renderer.uiImage?.pngData().map(RecapExport.init(data:))
    }
}

private struct StoryEditorBow: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.appCherry)
                .frame(width: 20, height: 13)
                .rotationEffect(.degrees(25))
                .offset(x: -8)
            Capsule()
                .fill(Color.appCherry)
                .frame(width: 20, height: 13)
                .rotationEffect(.degrees(-25))
                .offset(x: 8)
            Circle()
                .fill(Color.appButter)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(Color.appCard, lineWidth: 1.5))
        }
        .shadow(color: Color.appChocolate.opacity(0.16), radius: 2, y: 2)
    }
}
