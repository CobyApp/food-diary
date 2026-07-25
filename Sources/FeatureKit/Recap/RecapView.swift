import ClientKit
import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

public struct RecapExport: Transferable {
    let data: Data

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName("foodie-diary-week.png")
    }
}

public struct RecapCardView: View {
    let images: [UIImage]
    let mealCount: Int
    let rangeText: String

    public init(images: [UIImage], mealCount: Int, rangeText: String) {
        self.images = images
        self.mealCount = mealCount
        self.rangeText = rangeText
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("이번 주 한 끼")
                    .font(.appTitle)
                    .foregroundStyle(.appInk)
                Text(L10n.format("recap.meals", mealCount, rangeText))
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
                Text("FOODIE DIARY / WEEKLY")
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
    @State private var export: RecapExport?

    public init(store: StoreOf<RecapFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                VStack(spacing: 20) {
                    if store.isLoading {
                        KitschLoadingView(
                            "이번 주 카드를 만드는 중",
                            messages: ["맛있는 순간을 한 장에 모으고 있어요"]
                        )
                        .padding(24)
                    } else if store.weekCutouts.isEmpty {
                        EmptyState(
                            systemImage: "film.stack",
                            title: "이번 주 기록이 없어요",
                            subtitle: "한 끼를 담으면 주간 카드가 만들어져요!"
                        )
                    } else {
                        card
                        if let export {
                            ShareLink(item: export, preview: SharePreview("이번 주 한 끼")) {
                                Label("카드 공유하기", systemImage: "square.and.arrow.up")
                                    .font(.appSection)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.appBlue, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 24)
                        }
                    }
                }
            }
            .navigationTitle("주간 리캡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { store.send(.close) }
                }
            }
        }
        .task { store.send(.onAppear) }
        .task(id: store.weekCutouts) {
            let names = store.weekCutouts.map(\.fileName)
            images = await CutoutImageLoader.shared.images(
                fileNames: names,
                maxPixelDimension: 720
            )
            await renderExport()
        }
    }

    private var card: some View {
        RecapCardView(
            images: images,
            mealCount: store.mealCount,
            rangeText: store.rangeText
        )
        .softShadow()
    }

    @MainActor
    private func renderExport() async {
        guard !images.isEmpty else {
            export = nil
            return
        }
        let renderer = ImageRenderer(content:
            RecapCardView(
                images: images,
                mealCount: store.mealCount,
                rangeText: store.rangeText
            )
        )
        renderer.scale = 3
        export = renderer.uiImage?.pngData().map(RecapExport.init(data:))
    }
}
