import SwiftUI
import ComposableArchitecture
import Models

public struct GachaView: View {
    @Bindable var store: StoreOf<GachaFeature>
    @State private var revealResult = false
    @State private var drumTurns = 0.0
    @State private var drumShake: CGFloat = 0        // quick lateral jitter on lever pull
    @State private var capsuleDrop: CGFloat = -140   // y offset of the dispensed capsule
    @State private var capsuleOpen = false
    @State private var capsuleSquash: CGFloat = 1    // landing squash-and-stretch factor
    public init(store: StoreOf<GachaFeature>) { self.store = store }

    public var body: some View {
        ZStack {
            PaperBackground()
            if let result = store.result, revealResult {
                ResultCard(cutout: result, info: store.resultInfo,
                           onAgain: {
                               capsuleDrop = -140
                               capsuleOpen = false
                               capsuleSquash = 1
                               store.send(.playAgain)
                           },
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
                        // Quick shake on the drum as the lever is pulled.
                        withAnimation(.easeInOut(duration: 0.09).repeatCount(4, autoreverses: true)) {
                            drumShake = 5
                        }
                        withAnimation(.easeOut(duration: 0.5).delay(0.36)) { drumShake = 0 }
                        store.send(.pullLever)
                    }
                    .disabled(store.isSpinning)
                    .padding(.horizontal, 42)
                    OutlineButton("게임 나가기") { store.send(.close) }
                }
                .padding(24)
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: revealResult)
        .task(id: store.result?.id) {
            guard store.result != nil else {
                revealResult = false
                capsuleDrop = -140
                capsuleOpen = false
                capsuleSquash = 1
                return
            }
            // 1) capsule falls into the tray
            withAnimation(.interpolatingSpring(stiffness: 170, damping: 12)) { capsuleDrop = 26 }
            try? await Task.sleep(for: .milliseconds(520))
            // squash-and-stretch bounce as the capsule lands
            withAnimation(.easeOut(duration: 0.09)) { capsuleSquash = 0.86 }
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.interpolatingSpring(stiffness: 320, damping: 12)) { capsuleSquash = 1 }
            // 2) it splits open, revealing the cutout
            withAnimation(.spring(response: 0.42, dampingFraction: 0.6)) { capsuleOpen = true }
            try? await Task.sleep(for: .milliseconds(700))
            // 3) hand off to the result card
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
                .offset(x: drumShake)
                .overlay {
                    // Glass shine on the drum's dome.
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.55), Color.white.opacity(0.02)],
                                startPoint: .topLeading, endPoint: .center
                            )
                        )
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }

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
                .animation(.interpolatingSpring(stiffness: 220, damping: 9), value: store.isSpinning)
        }
        .overlay(alignment: .top) { WashiTape(.appLavender).offset(y: -8) }
        .overlay(alignment: .bottom) {
            if let result = store.result, !revealResult { dispensedCapsule(result) }
        }
        .softShadow()
    }

    @ViewBuilder
    private func dispensedCapsule(_ cutout: CutoutSnapshot) -> some View {
        ZStack {
            // Two halves that part when the capsule opens.
            Circle()
                .fill(Color.appPink)
                .frame(width: 96, height: 96)
                .mask(Rectangle().frame(height: 48).offset(y: -24))
                .offset(y: capsuleOpen ? -30 : 0)
            Circle()
                .fill(Color.appButter)
                .frame(width: 96, height: 96)
                .mask(Rectangle().frame(height: 48).offset(y: 24))
                .offset(y: capsuleOpen ? 30 : 0)
            CutoutImage(fileName: cutout.fileName)
                .frame(width: 74, height: 74)
                .scaleEffect(capsuleOpen ? 1.15 : 0.6)
                .opacity(capsuleOpen ? 1 : 0)
        }
        .offset(y: capsuleDrop)
        .scaleEffect(x: 1 / capsuleSquash, y: capsuleSquash, anchor: .bottom)
        .overlay(alignment: .center) {
            // Sparkle burst radiating outward when the capsule opens.
            ForEach(0..<5, id: \.self) { index in
                let angle = Double(index) / 5 * 2 * .pi
                KitschSparkle()
                    .fill(Color.appButter)
                    .frame(width: 22, height: 22)
                    .offset(x: cos(angle) * 44, y: sin(angle) * 44)
                    .opacity(capsuleOpen ? 1 : 0)
                    .scaleEffect(capsuleOpen ? 1 : 0.2)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.6).delay(Double(index) * 0.04),
                        value: capsuleOpen
                    )
            }
        }
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
