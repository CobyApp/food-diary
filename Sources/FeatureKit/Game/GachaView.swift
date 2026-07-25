import SwiftUI
import ComposableArchitecture

public struct GachaView: View {
    @Bindable var store: StoreOf<GachaFeature>
    public init(store: StoreOf<GachaFeature>) { self.store = store }

    public var body: some View {
        ZStack {
            Color.appMilk.ignoresSafeArea()
            if let result = store.result {
                ResultCard(cutout: result, place: store.resultPlace,
                           onAgain: { store.send(.playAgain) },
                           onClose: { store.send(.close) })
            } else {
                VStack(spacing: 24) {
                    Text("🎰").font(.system(size: 90))
                    Text("가챠 뽑기").font(.appDisplay).foregroundStyle(.appInk)
                    Text("레버를 당겨 오늘의 메뉴를 뽑아요").font(.appBody).foregroundStyle(.appMuted)
                    PillButton("레버 당기기") { store.send(.pullLever) }
                        .padding(.horizontal, 60)
                    Button("닫기") { store.send(.close) }.foregroundStyle(.appMuted)
                }
                .padding(24)
            }
        }
        .animation(.spring(duration: 0.4), value: store.result)
    }
}
