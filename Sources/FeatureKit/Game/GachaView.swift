import SwiftUI
import ComposableArchitecture
import Models

public struct GachaView: View {
    @Bindable var store: StoreOf<GachaFeature>
    @State private var revealResult = false
    @State private var drumTurns = 0.0
    public init(store: StoreOf<GachaFeature>) { self.store = store }

    public var body: some View {
        ZStack {
            PaperBackground()
            if let result = store.result, revealResult {
                ResultCard(cutout: result, place: store.resultPlace,
                           onAgain: { store.send(.playAgain) },
                           onClose: { store.send(.close) })
            } else {
                VStack(spacing: 18) {
                    gameHeader("캡슐 뽑기", subtitle: "레버를 내려 오늘의 한 끼를 꺼내요")
                    Spacer()
                    capsuleMachine
                    Spacer()
                    PillButton(store.isSpinning ? "캡슐 섞는 중" : "레버 당기기") {
                        guard !store.isSpinning else { return }
                        withAnimation(.easeInOut(duration: 1.05)) { drumTurns += 4 }
                        store.send(.pullLever)
                    }
                    .disabled(store.isSpinning)
                    .padding(.horizontal, 42)
                    Button("게임 나가기") { store.send(.close) }
                        .font(.appCaption).foregroundStyle(.appMuted)
                }
                .padding(24)
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: revealResult)
        .task(id: store.result?.id) {
            guard store.result != nil else {
                revealResult = false
                return
            }
            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { revealResult = true }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: store.isSpinning)
    }

    private var capsuleMachine: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(Color.appBlue.opacity(0.32))
                    Circle().stroke(Color.appChocolate, lineWidth: 4)
                    ForEach(Array(store.cutouts.prefix(5).enumerated()), id: \.element.id) { index, cutout in
                        capsule(index: index, cutout: cutout)
                    }
                }
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(drumTurns * 360))
                .clipped()

                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.appPink)
                    .frame(width: 220, height: 135)
                    .overlay {
                        VStack(spacing: 10) {
                            KitschIcon("arrow.down.circle.fill", background: .appButter, size: 52)
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.appChocolate)
                                .frame(width: 90, height: 18)
                        }
                    }
            }
            Capsule()
                .fill(Color.appCherry)
                .frame(width: 28, height: 118)
                .overlay(alignment: .top) {
                    Circle().fill(Color.appButter).frame(width: 48, height: 48).offset(y: -12)
                }
                .offset(x: 22, y: 64)
                .rotationEffect(.degrees(store.isSpinning ? 26 : 0), anchor: .bottom)
        }
        .overlay(alignment: .top) { WashiTape(.appLavender).offset(y: -8) }
        .softShadow()
    }

    private func gameHeader(_ title: String, subtitle: String) -> some View {
        VStack(spacing: 5) {
            Text(L10n.text(title)).font(.appDisplay).foregroundStyle(.appInk)
            Text(L10n.text(subtitle)).font(.appBody).foregroundStyle(.appMuted)
        }
    }

    private func capsule(index: Int, cutout: CutoutSnapshot) -> some View {
        let angle = Double(index) * 1.25
        let x = CGFloat(cos(angle) * 62)
        let y = CGFloat(sin(angle) * 62)
        let colors: [Color] = [.appPink, .appButter, .appLavender]
        return Circle()
            .fill(colors[index % colors.count])
            .frame(width: 62, height: 62)
            .overlay { CutoutImage(fileName: cutout.fileName).padding(9) }
            .offset(x: x, y: y)
    }
}
