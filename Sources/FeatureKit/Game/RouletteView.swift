import SwiftUI
import ComposableArchitecture
import Models

public struct RouletteView: View {
    @Bindable var store: StoreOf<RouletteFeature>
    public init(store: StoreOf<RouletteFeature>) { self.store = store }

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            if let result = store.result {
                ResultCard(cutout: result, place: store.resultPlace,
                           onAgain: { store.send(.playAgain) },
                           onClose: { store.send(.close) })
            } else {
                VStack(spacing: 18) {
                    Text("룰렛 슬롯 🎡").font(.appDisplay).foregroundStyle(.appInk)
                    ScrollView(.vertical) {
                        VStack(spacing: 10) {
                            ForEach(Array(store.reel.enumerated()), id: \.offset) { _, cutout in
                                StickerTile(tint: .rotating(cutout.id.hashValue)) {
                                    CutoutImage(fileName: cutout.fileName)
                                }
                                .frame(height: 90)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    PillButton("스핀!") { store.send(.spin) }.padding(.horizontal, 60)
                    Button("닫기") { store.send(.close) }.foregroundStyle(.appMuted)
                }
                .padding(24)
                .task { store.send(.appear) }
            }
        }
        .animation(.spring(duration: 0.4), value: store.result)
    }
}
